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

require 'mirah'

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

    class Body
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.body(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class ScopedBody
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.scoped_body(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Import
      def compile(compiler, expression)
        # TODO: what does it mean for import to be an expression?
        compiler.import(short, long)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
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

    class Print
      def compile(compiler, expression)
        # TODO: what does it mean for printline to be an expression?
        compiler.line(line_number)
        compiler.print(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Local
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          if captured? && scope.has_binding?
            compiler.captured_local(containing_scope, name, inferred_type)
          else
            compiler.local(containing_scope, name, inferred_type)
          end
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class LocalDeclaration
      def compile(compiler, expression)
        compiler.line(line_number)
        if captured? && scope.has_binding?
          compiler.captured_local_declare(containing_scope, name, type)
        else
          compiler.local_declare(containing_scope, name, type)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class LocalAssignment
      def compile(compiler, expression)
        compiler.line(line_number)
        if captured? && scope.has_binding?
          compiler.captured_local_assign(self, expression)
        else
          compiler.local_assign(containing_scope, name, inferred_type, expression, value)
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Script
      def compile(compiler, expression)
        # TODO: what does it mean for a script to be an expression? possible?
        compiler.define_main(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class MethodDefinition
      def compile(compiler, expression)
        # TODO: what does it mean for a method to be an expression?
        compiler.define_method(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class ConstructorDefinition
      def compile(compiler, expression)
        compiler.constructor(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Arguments
      def compile(compiler, expression)
        # TODO: what does it mean for a method to be an expression?
        args.each {|arg| compiler.declare_argument(arg.name, arg.inferred_type)} if args
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Noop
      def compile(compiler, expression)
        # TODO: what does it mean for a noop to be an expression
        # nothing
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class If
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.branch(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Condition
      def compile(compiler, expression)
        # TODO: can a condition ever be an expression? I don't think it can...
        compiler.line(line_number)
        predicate.compile(compiler, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class FunctionalCall
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.self_call(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Call
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.call(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Super
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.super_call(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Loop
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.loop(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

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

    class AccessLevel
      def compile(compiler, expression); end
    end

    class Return
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.return(self)
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

    class Break
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.break(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Next
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.next(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Redo
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.redo(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Raise
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler._raise(exception)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Rescue
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.rescue(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Ensure
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.ensure(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Self
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.compile_self
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class BindingReference
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.binding_reference
        end
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end
  end
end
