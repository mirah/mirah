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

require 'mirah/generator'
require 'mirah/util/class_loader'

module Mirah
  module Commands
    class Run < Base
      def execute
        execute_base do
          main = nil

          
          # generate all bytes for all classes
          class_map = generate_class_map 
          
          # load all classes
          main = load_classes_and_find_main(class_map)
          
          # run the main method we found
          run_main(main)
        end
      end
      
      def command_name
        :run
      end
      
      private

      def generate_class_map
        generator = Mirah::Generator.new(@state, @state.compiler_class, false, @state.verbose)

        class_map = {}
        generator.generate(args).each do |result|
          class_map[result.classname.gsub(/\//, '.')] = Mirah::Util::ClassLoader.binary_string result.bytes
        end
        class_map
      end
      
      def load_classes_and_find_main(class_map)
        main = nil
        dcl = Mirah::Util::ClassLoader.new(JRuby.runtime.jruby_class_loader, class_map)
        class_map.each do |name,|
          cls = dcl.load_class(name)
          # TODO: using first main; find correct one?
          main ||= cls.get_method("main", java::lang::String[].java_class)
        end
        main
      end
      
      def run_main(main)
        if main
          begin
            main.invoke(nil, [args.to_java(:string)].to_java)
          rescue java.lang.Exception => e
            e = e.cause if e.cause
            raise e
          end
        else
          $stderr.puts "No main found"
          exit 1
        end
      end
    end
  end
end
