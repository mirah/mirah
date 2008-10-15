require 'duby'

module Duby
  module AST
    class Fixnum
      def compile(compiler, expression)
        if expression
          compiler.fixnum(literal)
        end
      end
    end
    
    class String
      def compile(compiler, expression)
        if expression
          compiler.string(literal)
        end
      end
    end
    
    class Float
      def compile(compiler, expression)
        if expression
          compiler.float(literal)
        end
      end
    end
    
    class Boolean
      def compile(compiler, expression)
        if expression
          compiler.boolean(literal)
        end
      end
    end
    
    class Body
      def compile(compiler, expression)
        # all except the last element in a body of code is treated as a statement
        i, last = 0, children.size - 1
        while i < last
          children[i].compile(compiler, false)
          i += 1
        end
        # last element is an expression only if the body is an expression
        children[last].compile(compiler, expression)
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
          compiler.constant(self)
        end
      end
    end

    class PrintLine
      def compile(compiler, expression)
        # TODO: what does it mean for printline to be an expression?
        compiler.println(self)
      end
    end
    
    class Local
      def compile(compiler, expression)
        if expression
          compiler.local(name, inferred_type)
        end
      end
    end
    
    class LocalAssignment
      def compile(compiler, expression)
        compiler.local_assign(name, inferred_type, expression) {
          value.compile(compiler, true)
        }
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
        compiler.define_method(name, signature, arguments, body)
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
        compiler.branch(self, expression)
      end
    end
    
    class Condition
      def compile(compiler, expression)
        # TODO: can a condition ever be an expression? I don't think it can...
        predicate.compile(compiler)
      end
    end
    
    class FunctionalCall
      def compile(compiler, expression)
        compiler.self_call(self, expression)
      end
    end
    
    class Call
      def compile(compiler, expression)
        compiler.call(self, expression)
      end
    end
    
    class Loop
      def compile(compiler, expression)
        compiler.loop(self, expression)
      end
    end
  end
end