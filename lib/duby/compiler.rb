require 'duby'

module Duby
  module AST
    class Fixnum
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.fixnum(literal)
        end
      end
    end
    
    class String
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.string(literal)
        end
      end
    end

    class StringConcat
      def compile(compiler, expression)
        compiler.build_string(children, expression)
      end
    end

    class ToString
      def compile(compiler, expression)
        compiler.to_string(body, expression)
      end
    end
    
    class Float
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.float(literal)
        end
      end
    end
    
    class Boolean
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.boolean(literal)
        end
      end
    end

    class Array
      def compile(compiler, expression)
        compiler.array(self, expression)
      end
    end
    
    class Body
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.body(self, expression)
      end
    end

    class Import
      def compile(compiler, expression)
        # TODO: what does it mean for import to be an expression?
        compiler.import(short, long)
      end
    end

    class Constant
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.constant(self)
        end
      end
    end

    class Print
      def compile(compiler, expression)
        # TODO: what does it mean for printline to be an expression?
        compiler.line(line_number)
        compiler.print(self)
      end
    end
    
    class Local
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.local(name, inferred_type)
        end
      end
    end

    class LocalDeclaration
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.local_declare(name, type)
      end
    end
    
    class LocalAssignment
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.local_assign(name, inferred_type, expression, value)
      end
    end
    
    class Script
      def compile(compiler, expression)
        # TODO: what does it mean for a script to be an expression? possible?
        compiler.define_main(body)
      end
    end
    
    class MethodDefinition
      def compile(compiler, expression)
        # TODO: what does it mean for a method to be an expression?
        compiler.define_method(self)
      end
    end
    
    class ConstructorDefinition
      def compile(compiler, expression)
        compiler.constructor(self)
      end
    end
    
    class Arguments
      def compile(compiler, expression)
        # TODO: what does it mean for a method to be an expression?
        args.each {|arg| compiler.declare_argument(arg.name, arg.inferred_type)} if args
      end
    end
    
    class Noop
      def compile(compiler, expression)
        # TODO: what does it mean for a noop to be an expression
        # nothing
      end
    end
    
    class If
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.branch(self, expression)
      end
    end
    
    class Condition
      def compile(compiler, expression)
        # TODO: can a condition ever be an expression? I don't think it can...
        compiler.line(line_number)
        predicate.compile(compiler, expression)
      end
    end
    
    class FunctionalCall
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.self_call(self, expression)
      end
    end
    
    class Call
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.call(self, expression)
      end
    end

    class Super
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.super_call(self, expression)
      end
    end
    
    class Loop
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.loop(self, expression)
      end
    end
    
    class ClassDefinition
      def compile(compiler, expression)
        compiler.define_class(self, expression)
      end
    end

    class FieldDeclaration
      def compile(compiler, expression)
        compiler.field_declare(name, inferred_type, annotations)
      end
    end

    class FieldAssignment
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.field_assign(name, inferred_type, expression, value, annotations)
      end
    end

    class Field
      def compile(compiler, expression)
        compiler.line(line_number)
        if expression
          compiler.field(name, inferred_type, annotations)
        end
      end
    end

    class Return
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.return(self)
      end
    end

    class EmptyArray
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.empty_array(component_type, size)
        end
      end
    end
    
    class Null
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.null
        end
      end
    end
    
    class Break
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.break(self)
      end
    end
    
    class Next
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.next(self)
      end
    end
    
    class Redo
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.redo(self)
      end
    end

    class Raise
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler._raise(exception)
      end
    end

    class Rescue
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.rescue(self, expression)
      end
    end
    
    class Ensure
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.ensure(self, expression)
      end
    end
    
    class Self
      def compile(compiler, expression)
        if expression
          compiler.line(line_number)
          compiler.compile_self
        end
      end
    end
  end
end