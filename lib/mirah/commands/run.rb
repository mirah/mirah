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

module Mirah
  module Commands
    class Run < Base
      def execute
        execute_base do
          main = nil
          class_map = {}
          
          # generate all bytes for all classes
          generator = Mirah::Generator.new(@state.compiler_class, false, @state.verbose)
          
          generator.generate(args).each do |result|
            class_map[result.classname.gsub(/\//, '.')] = result.bytes
          end
          
          # load all classes
          main = load_classes_and_find_main(class_map)
          
          # run the main method we found
          run_main(main)
        end
      end
      
      private
      
      def load_classes_and_find_main(class_map)
        main = nil
        dcl = Mirah::ClassLoader.new(JRuby.runtime.jruby_class_loader, class_map)
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
          puts "No main found" unless @state.version_printed || @state.help_printed
        end
      end
    end
  end
end