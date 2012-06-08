# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'appengine-sdk'
require 'mirah_task'
require 'java'
require 'open-uri'
require 'rake'
require 'yaml'

module AppEngine::Rake
  SERVLET = AppEngine::SDK::SDK_ROOT + '/lib/shared/servlet-api.jar'
  APIS = AppEngine::SDK::API_JAR
  TOOLS = AppEngine::SDK::TOOLS_JAR

  CLASSPATH = []
  CLASSPATH << SERVLET
  CLASSPATH << APIS
  CLASSPATH << TOOLS

  class AppEngineTask < Rake::Task
    def initialize(*args, &block)
      super
      AppEngineTask.tasks << self
    end

    def init(src, war)
      @src = src
      @war = war
      unless CLASSPATH.include?(webinf_classes)
        CLASSPATH << webinf_classes
      end
      webinf_lib_jars.each do |jar|
        CLASSPATH << jar unless CLASSPATH.include?(jar)
      end
      Mirah.source_paths << src
      Mirah.dest_paths << webinf_classes
      Mirah.compiler_options = ['--classpath', Mirah::Env.encode_paths(CLASSPATH)]
      directory(webinf_classes)
      directory(webinf_lib)

      file_create api_jar => webinf_lib do
        puts 'Coping apis'
        cp APIS, api_jar
      end

      task :server => [name] do
        check_for_updates
        args = [
          'java', '-cp', TOOLS,
          'com.google.appengine.tools.KickStart',
          'com.google.appengine.tools.development.DevAppServerMain',
          @war
        ]
        system *args
        @done = true
        @update_thread.join
      end
      task :upload => [name] do
        Java::ComGoogleAppengineTools::AppCfg.main(
            ['update', @war].to_java(:string))
      end

      enhance([api_jar])
    end

    def real_prerequisites
      prerequisites.map {|n| application[n, scope]}
    end

    def check_for_updates
      @update_thread = Thread.new do
        # Give the server time to start
        next_time = Time.now + 5
        until @done
          sleep_time = next_time - Time.now
          sleep(sleep_time) if sleep_time > 0
          next_time = Time.now + 1
          update
        end
      end
    end

    def update
      begin
        timestamp = app_yaml_timestamp
        @last_app_yaml_timestamp ||= timestamp
        updated = false
        real_prerequisites.each do |dep|
          if dep.needed?
            puts "Executing #{dep.name}"
            dep.execute
            updated = true
          end
        end
        if updated || (timestamp != @last_app_yaml_timestamp)
          begin
            open('http://localhost:8080/_ah/reloadwebapp')
            @last_app_yaml_timestamp = timestamp
          rescue OpenURI::HTTPError
          end
        end
      rescue Exception
        puts $!, $@
      end
    end

    def app_yaml_timestamp
      if File.exist?(app_yaml)
        File.mtime(app_yaml)
      end
    end

    def app_yaml
      @war + '/WEB-INF/app.yaml'
    end

    def webinf_classes
      @war + '/WEB-INF/classes'
    end

    def webinf_lib
      @war + '/WEB-INF/lib'
    end

    def api_jar
      File.join(webinf_lib, File.basename(APIS))
    end

    def webinf_lib_jars
      Dir.glob(webinf_lib + '/*.jar')
    end
  end
end

def appengine_app(*args, &block)
  deps = []
  if args[-1].kind_of?(Hash)
    hash = args.pop
    arg = hash.keys[0]
    deps = hash[arg]
    args << arg
  end
  name, src, war = args
  task = AppEngine::Rake::AppEngineTask.define_task(name => deps, &block)
  src = File.expand_path(src || 'src')
  war = File.expand_path(war || 'war')
  task.init(src, war)
  task
end
