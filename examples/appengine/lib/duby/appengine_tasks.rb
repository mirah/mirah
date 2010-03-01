require 'appengine-sdk'
require 'appengine-tools/appcfg'
require 'appengine-tools/dev_appserver'
require 'appengine-tools/web-xml'
require 'appengine-tools/xml-formatter'
require 'duby_task'
require 'java'
require 'open-uri'
require 'rake'
require 'yaml'

Duby.compiler_options.concat %w"-p datastore"
AppEngine::Development::JRubyDevAppserver::ARGV = []
module AppEngine::Rake
  SERVLET = AppEngine::SDK::SDK_ROOT +
            '/lib/shared/geronimo-servlet_2.5_spec-1.2.jar'
  APIS = AppEngine::SDK::API_JAR

  $CLASSPATH << SERVLET
  $CLASSPATH << APIS

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
      Duby.source_path = src
      Duby.dest_path = webinf_classes
      directory(webinf_classes)
      directory(generated)
      file_create dummy_config_ru do |t|
        touch t.name
      end
      file_create gemfile do |t|
        open(t.name, 'w') do |gems|
          gems.puts('bundle_path ".gems/bundler_gems"')
        end
      end
      file web_xml => [webinf_classes, real_config_ru] do
        config_ru = IO.read(real_config_ru)
        builder = WebXmlBuilder.new do
          eval config_ru, nil, 'config.ru', 1
        end
        open(web_xml, 'w') do |webxml|
          xml = AppEngine::Rack::XmlFormatter.format(builder.to_xml)
          webxml.write(xml)
        end
        open(aeweb_xml, 'w') do |aeweb|
          xml = AppEngine::Rack::XmlFormatter.format(AppEngine::Rack.app.to_xml)
          aeweb.write(xml)
        end
      end
      file build_status => [web_xml, dummy_config_ru, aeweb_xml, generated] do
        open(build_status, 'w') do |status_file|
          status = {
            :config_ru => File.stat(dummy_config_ru).mtime,
            :web_xml => File.stat(web_xml).mtime,
            :aeweb_xml => File.stat(aeweb_xml).mtime,
          }
          status_file.write(status.to_yaml)
        end
      end

      task :server => [name, build_status] do
        # Begin horrible hacks
        if AppEngine::Development::JRubyDevAppserver::ARGV.empty?
          AppEngine::Development::JRubyDevAppserver::ARGV << @war
        end
        class << AppEngine::Development::JRubyDevAppserver
          def exec(*args)
            sh *args
          end
        end
        # End horrible hacks
        check_for_updates
        AppEngine::Development::JRubyDevAppserver.run([@war])
        @done = true
        @update_thread.join
      end
      task :upload => [name, build_status] do
        AppEngine::Admin::JRubyAppCfg.main(['update', @war])
      end

      enhance([web_xml])
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
      updated = false
      real_prerequisites.each do |dep|
        if dep.needed?
          dep.execute
          updated = true
        end
      end
      if updated
        #touch aeweb_xml
        open('http://localhost:8080/_ah/reloadwebapp')
      end
    end

    def webinf_classes
      @war + '/WEB-INF/classes'
    end

    def aeweb_xml
      @war + '/WEB-INF/appengine-web.xml'
    end

    def web_xml
      @war + '/WEB-INF/web.xml'
    end

    def real_config_ru
      @src + '/config.ru'
    end

    def dummy_config_ru
      @war + '/config.ru'
    end

    def generated
      @war + '/WEB-INF/appengine-generated'
    end

    def build_status
      generated + '/build_status.yaml'
    end

    def gemfile
      @war + '/Gemfile'
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