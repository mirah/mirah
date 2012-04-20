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

require 'mirah/util/logging'

module Mirah
  module Util

    class ArgumentProcessor
      def initialize(state, args)
        @state = state
        @args = args
      end

      attr_accessor :state, :args

      def process
        state.args = args
        while args.length > 0 && args[0] =~ /^-/
          case args[0]
          when '--classpath', '-c'
            args.shift
            Mirah::Env.decode_paths(args.shift, $CLASSPATH)
          when '--cd'
            args.shift
            Dir.chdir(args.shift)
          when '--dest', '-d'
            args.shift
            state.destination = File.join(File.expand_path(args.shift), '')
          when '-e'
            break
          when '--explicit-packages'
            args.shift
            Mirah::AST::Script.explicit_packages = true
          when '--help', '-h'
            print_help
            throw :exit, 0
          when '--java', '-j'
            if state.command == :compile
              require 'mirah/jvm/compiler/java_source'
              state.compiler_class = Mirah::JVM::Compiler::JavaSource
              args.shift
            else
              puts "-j/--java flag only applies to \"compile\" mode."
              print_help
              throw :exit, 1
            end
          when '--jvm'
            args.shift
            state.set_jvm_version(args.shift)
          when '-I'
            args.shift
            $: << args.shift
          when '--plugin', '-p'
            args.shift
            plugin = args.shift
            require "mirah/plugin/#{plugin}"
          when '--verbose', '-V'
            Mirah::Logging::MirahLogger.level = Mirah::Logging::Level::FINE
            state.verbose = true
            args.shift
          when '--vmodule'
            args.shift
            spec = args.shift
            spec.split(',').each do |item|
              logger, level = item.split("=")
              logger = java.util.logging.Logger.getLogger(logger)
              (state.loggers ||= []) << logger
              level = java.util.logging.Level.parse(level)
              logger.setLevel(level)
            end
          when '--no-color'
            args.shift
            Mirah::Logging::MirahHandler.formatter = Mirah::Logging::LogFormatter.new(false)
          when '--version', '-v'
            args.shift
            print_version
            throw :exit, 0 if args.empty?
          when '--no-save-extensions'
            args.shift
            state.save_extensions = false
          else
            puts "unrecognized flag: " + args[0]
            print_help
            throw :exit, 1
          end
        end
        state.destination ||= File.join(File.expand_path('.'), '')
        state.compiler_class ||= Mirah::JVM::Compiler::JVMBytecode
      end

      def print_help
        puts "#{$0} [flags] <files or -e SCRIPT>
        -c, --classpath PATH\tAdd PATH to the Java classpath for compilation
        --cd DIR\t\tSwitch to the specified DIR befor compilation
        -d, --dir DIR\t\tUse DIR as the base dir for compilation, packages
        -e CODE\t\tCompile or run the inline script following -e
        \t\t\t  (the class will be named \"DashE\")
        --explicit-packages\tRequire explicit 'package' lines in source
        -h, --help\t\tPrint this help message
        -I DIR\t\tAdd DIR to the Ruby load path before running
        -j, --java\t\tOutput .java source (compile mode [mirahc] only)
        --jvm VERSION\t\tEmit JVM bytecode targeting specified JVM
        \t\t\t  version (1.4, 1.5, 1.6, 1.7)
        -p, --plugin PLUGIN\trequire 'mirah/plugin/PLUGIN' before running
        -v, --version\t\tPrint the version of Mirah to the console
        -V, --verbose\t\tVerbose logging
        --vmodule logger.name=LEVEL[,...]\t\tSet the Level for the specified Java loggers"
        state.help_printed = true
      end

      def print_version
        puts "Mirah v#{Mirah::VERSION}"
        state.version_printed = true
      end
    end
  end
end