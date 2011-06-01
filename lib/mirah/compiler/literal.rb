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
  module AST
    class Fixnum
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.fixnum(inferred_type, literal)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Regexp
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.regexp(literal)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class String
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.string(literal)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class StringConcat
      def compile(compiler, expression)
        compiler.build_string(children, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class ToString
      def compile(compiler, expression)
        compiler.to_string(body, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Float
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.float(inferred_type, literal)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Boolean
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.boolean(literal)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Array
      def compile(compiler, expression)
        compiler.array(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Null
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.null
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class EmptyArray
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.empty_array(component_type, size)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Self
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.compile_self(compiler.get_scope(self))
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end
  end
end