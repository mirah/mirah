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
    class ClassDefinition
      def compile(compiler, expression)
        compiler.define_class(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end
    
    class ClosureDefinition
      def compile(compiler, expression)
        compiler.define_closure(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class AccessLevel
      def compile(compiler, expression); end
    end

    class FieldDeclaration
      def compile(compiler, expression)
        compiler.field_declare(name, inferred_type, annotations, static)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class FieldAssignment
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.field_assign(name, inferred_type, expression, value, annotations, static)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Field
      def compile(compiler, expression)
        compiler.line(line_number)
        if expression
          compiler.field(name, inferred_type, annotations, static)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Include
      def compile(compiler, expression); end
    end
    
    class Constant
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.constant(self)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end
  end
end