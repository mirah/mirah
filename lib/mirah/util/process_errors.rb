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
  module Util
    module ProcessErrors
      java_import 'org.mirah.typer.ErrorType'

      # errors - array of NodeErrors
      def process_errors(errors)
        errors.each do |ex|
          if ex.kind_of?(ErrorType)
            ex.message.each do |pair|
              message, position = pair.to_a
              if position
                Mirah.print_error(message, position)
              else
                puts message
              end
            end if ex.message
          else
            puts ex
            if ex.respond_to?(:node) && ex.node
              Mirah.print_error(ex.message, ex.position)
            else
              puts ex.message
            end
            error(ex.backtrace.join("\n")) if self.logging?
          end
        end
        throw :exit, 1 unless errors.empty?
      end

      java_import 'mirah.lang.ast.NodeScanner'
      class ErrorCollector < NodeScanner
        def initialize(typer)
          super()
          @errors = {}
          @typer = typer
        end
        def exitDefault(node, arg)
          type = @typer.getInferredType(node)
          type = type.resolve if type
          if (type && type.isError)
            @errors[type] ||= begin
              if type.message.size == 1
                m = type.message[0]
                if m.size == 1
                  m << node rescue nil
                elsif m.size == 2 && m[1] == nil
                  m[1] = node.position rescue nil
                end
              elsif type.message.size == 0
                type.message << ["Error", node.position]
              end
              type
            end
          end
          nil
        end
        def errors
          @errors.values
        end
      end

      def process_inference_errors(typer, nodes)
        errors = []
        nodes.each do |ast|
          collector = ErrorCollector.new(typer)
          ast.accept(collector, nil)
          errors.concat(collector.errors)
        end
        failed = !errors.empty?
        if failed
          if block_given?
            yield(errors)
          else
            puts "Inference Error:"
            process_errors(errors)
          end
        end
      end
    end
  end
end
