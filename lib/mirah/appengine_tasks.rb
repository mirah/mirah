require 'appengine-sdk'
require 'mirah_task'
require 'java'
require 'open-uri'
require 'rake'
require 'yaml'

module AppEngine::Rake
  SERVLET = AppEngine::SDK::SDK_ROOT +
            '/lib/shared/geronimo-servlet_2.5_spec-1.2.jar'
  APIS = AppEngine::SDK::API_JAR
  TOOLS = AppEngine::SDK::TOOLS_JAR

  $CLASSPATH << SERVLET
  $CLASSPATH << APIS
  $CLASSPATH << TOOLS

  class AppEngineTask < Rake::Task
    def initialize(*args, &block)
      super
      AppEngineTask.tasks << self
    end

    def init(src, war)
      @src = src
      @war = war
      unless $CLASSPATH.include?(webinf_classes)
        $CLASSPATH << webinf_classes
      end
      webinf_lib_jars.each do |jar|
        $CLASSPATH << jar unless $CLASSPATH.include?(jar)
      end
      Duby.source_paths << src
      Duby.dest_paths << webinf_classes
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
        sh *args
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
      @war + '/app.yaml'
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