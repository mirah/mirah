require 'ant'
require 'appengine-sdk'

$: << '../../../lib'
require 'mirah_task'

JUNIT_JAR = '../../../javalib/junit.jar'
TESTING_JARS = [AppEngine::SDK::API_JAR, AppEngine::SDK::LABS_JAR, JUNIT_JAR] +
  AppEngine::SDK::RUNTIME_JARS.reject {|j| j =~ /appengine-local-runtime/}
TESTING_JARS.each {|jar| $CLASSPATH << jar}

# Duby.compiler_options = ['-V']

task :default => :test

task :init do
  mkdir_p 'dist'
  mkdir_p 'build'
end

task :clean do
  ant.delete :quiet => true, :dir => 'build'
  ant.delete :quiet => true, :dir => 'dist'
end

task :compile => :init do
  # build the Duby sources
  puts "Compiling Duby sources"
  mirahc 'com/google/appengine', :dir => 'src', :dest => 'build'
end

task :compile_test => :jar do
  puts "Compiling Duby tests"
  mirahc 'com/google/appengine', :dir => 'test', :dest => 'test',
         :options => ['--classpath', Dir.pwd + "/dist/dubydatastore.jar"]
end

task :jar => :compile do
  ant.jar :jarfile => 'dist/dubydatastore.jar' do
    fileset :dir => 'lib'
    fileset :dir => 'build'
  end
end

task :test => :compile_test do
  ant.junit :haltonfailure => 'true', :fork => 'true' do
    classpath :path => (TESTING_JARS + ['build', 'test']).join(":")
    batchtest do
      fileset :dir => "test" do
        include :name => '**/*Test.class'
      end
      formatter :type => 'plain', :usefile => 'false'
    end
  end
end