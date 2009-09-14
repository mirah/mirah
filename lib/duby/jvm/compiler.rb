require 'duby'
require 'duby/jvm/method_lookup'
require 'duby/jvm/types'
require 'duby/typer'
require 'duby/plugin/java'
require 'bitescript'

module Duby
  module AST
    class FunctionalCall
      attr_accessor :target
    end
  end
  
  module Compiler
    class JVM
      import java.lang.System
      import java.io.PrintStream
      include Duby::JVM::MethodLookup
      Types = Duby::JVM::Types

      class << self
        attr_accessor :verbose

        def log(message)
          puts "* [#{name}] #{message}" if JVM.verbose
        end
      end

      module JVMLogger
        def log(message); JVM.log(message); end
      end
      include JVMLogger

      class ImplicitSelf
        attr_reader :inferred_type
        
        def initialize(type)
          @inferred_type = type
        end
        
        def compile(compiler, expression)
          if expression
            compiler.method.this
          end
        end
      end
      
      attr_accessor :filename, :src, :method, :static, :class

      def initialize(filename)
        @filename = filename
        @src = ""
        @static = true

        @file = BiteScript::FileBuilder.new(filename)
        @class = @file.public_class(filename.split('.')[0])
      end

      def compile(ast, expression = false)
        ast.compile(self, expression)
        log "Compilation successful!"
      end

      def define_main(body)
        oldmethod, @method = @method, @class.main

        log "Starting main method"

        @method.start

        # declare argv variable
        # TODO type as String[]
        @method.local('argv')

        body.compile(self, false)

        @method.returnvoid
        @method.stop
        
        @method = oldmethod

        log "Main method complete!"
      end
      
      def define_method(name, signature, args, body)
        arg_types = if args.args
          args.args.map { |arg| arg.inferred_type }
        else
          []
        end
        return_type = signature[:return]
        if @static
          oldmethod, @method = @method, @class.public_static_method(name.to_s, return_type, *arg_types)
        else
          if name == "initialize"
            oldmethod, @method = @method, @class.public_constructor(*arg_types)
            @method.aload 0
            @method.invokespecial @method.object, "<init>", [@method.void]
          else
            oldmethod, @method = @method, @class.public_method(name.to_s, return_type, *arg_types)
          end
        end

        log "Starting new method #{name}(#{arg_types})"

        @method.start

        # declare all args so they get their values
        args.args.each {|arg| @method.local arg.name} if args.args
        
        expression = signature[:return] != Types::Void
        body.compile(self, expression) if body

        if name == "initialize"
          @method.returnvoid
        else
          signature[:return].return(@method)
        end
        
        @method.stop

        @method = oldmethod

        log "Method #{name}(#{arg_types}) complete!"
      end

      def define_class(class_def, expression)
        prev_class, @class = @class, class_def.inferred_type.define(@file)
        old_static, @static = @static, false

        class_def.body.compile(self, false)
        
        @class.stop
        @class = prev_class
        @static = old_static
      end
      
      def declare_argument(name, type)
        # declare local vars for arguments here
      end
      
      def branch(iff, expression)
        elselabel = @method.label
        donelabel = @method.label
        
        # this is ugly...need a better way to abstract the idea of compiling a
        # conditional branch while still fitting into JVM opcodes
        predicate = iff.condition.predicate
        if iff.body
          jump_if_not(predicate, elselabel)

          iff.body.compile(self, expression) if iff.body

          @method.goto(donelabel)
        else
          jump_if(predicate, donelabel)
        end

        elselabel.set!

        iff.else.compile(self, expression) if iff.else

        donelabel.set!
      end
      
      def loop(loop, expression)
        donelabel = @method.label
        beforelabel = @method.label
        
        # TODO: not checking "check first" or "negative"
        predicate = loop.condition.predicate
        
        # if an expression, make sure it will at least result in a null
        # TODO: make this result appropriate for primitive types as well
        @method.aconst_null if expression

        beforelabel.set!
        
        if loop.check_first
          if loop.negative
            # if condition, exit
            jump_if(predicate, donelabel)
          else
            # if not condition, exit
            jump_if_not(predicate, donelabel)
          end
        end
        
        # if expression, before each entry into the loop, pop previous result (or default null from above)
        # this leaves a result on the stack at the end
        @method.pop if expression
        
        loop.body.compile(self, expression)
        
        # if not an expression, we don't need to pop result each time
        
        unless loop.check_first
          if loop.negative
            # if not condition, continue
            jump_if_not(predicate, beforelabel)
          else
            # if condition, continue
            jump_if(predicate, beforelabel)
          end
        else
          @method.goto(beforelabel)
        end
        
        donelabel.set!
      end
      
      def jump_if(predicate, target)
        raise "Expected boolean, found #{predicate.inferred_type}" unless predicate.inferred_type == Types::Boolean
        predicate.compile(self, true)
        @method.ifne(target)
      end
      
      def jump_if_not(predicate, target)
        raise "Expected boolean, found #{predicate.inferred_type}" unless predicate.inferred_type == Types::Boolean
        predicate.compile(self, true)
        @method.ifeq(target)
      end
      
      def call(call, expression)

        target = call.target.inferred_type
        params = call.parameters.map do |param|
          param.inferred_type
        end
        method = target.get_method(call.name, params)
        if method
          method.call(self, call, expression)
        else
          raise "Missing method #{target}.#{call.name}(#{params.join ', '})"
        end
      end
      
      def self_call(fcall, expression)
        type = AST::type(@class.name)
        type = type.meta if @static
        fcall.target = ImplicitSelf.new(type)

        params = fcall.parameters.map do |param|
          param.inferred_type
        end
        method = type.get_method(fcall.name, params)
        unless method
          target = static ? @class.name : 'self'
        
          raise NameError, "No method %s.%s(%s)" %
              [target, fcall.name, params.join(', ')]
        end
        method.call(self, fcall, expression)
      end
      
      def local(name, type)
        type.load(@method, @method.local(name))
      end

      def local_assign(name, type, expression)
        declare_local(name, type)
        
        yield
        
        # if expression, dup the value we're assigning
        @method.dup if expression
        
        type.store(@method, @method.local(name))
      end

      def declared_locals
        @declared_locals ||= {}
      end

      def declare_local(name, type)
        # TODO confirm types are compatible
        unless declared_locals[name]
          declared_locals[name] = type
          @method.local(name, type.wide?)
        end
      end

      def local_declare(name, type)
        declare_local(name, type)
        type.init_value(@method)
        type.store(@method, @method.local(name))
      end

      def field(name, type)
        name = name[1..-1]

        # load self object unless static
        method.aload 0 unless static
        
        if static
          @method.getstatic(@class, name, type)
        else
          @method.getfield(@class, name, type)
        end
      end

      def declared_fields
        @declared_fields ||= {}
      end

      def declare_field(name, type)
        # TODO confirm types are compatible
        unless declared_fields[name]
          declared_fields[name] = type
          if static
            @class.private_static_field name, type
          else
            @class.private_field name, type
          end
        end
      end

      def field_declare(name, type)
        name = name[1..-1]
        declare_field(name, type)
      end

      def field_assign(name, type, expression)
        name = name[1..-1]

        real_type = declared_fields[name] || type
        
        declare_field(name, real_type)

        method.aload 0 unless static
        yield
        if expression
          instruction = 'dup'
          instruction << '2' if type.wide?
          instruction << '_x1' unless static
          method.send instruction
        end

        if static
          @method.putstatic(@class, name, real_type)
        else
          @method.putfield(@class, name, real_type)
        end
      end
      
      def string(value)
        @method.ldc(value)
      end

      def boolean(value)
        value ? @method.iconst_1 : @method.iconst_0
      end
      
      def null
        @method.aconst_null
      end
      
      def newline
        # TODO: line numbering
      end
      
      def generate
        @class.stop
        log "Generating classes..."
        @file.generate do |filename, builder|
          log "  #{builder.class_name}"
          if block_given?
            yield filename, builder
          else
            File.open(filename, 'w') {|f| f.write(builder.generate)}
          end
        end
        log "...done!"
      end
      
      def import(short, long)
      end

      def println(printline)
        @method.getstatic System, "out", PrintStream
        printline.parameters.each {|param| param.compile(self, true)}
        params = printline.parameters.map {|param| param.inferred_type.jvm_type}
        method = find_method(PrintStream.java_class, "println", params, false)
        if (method)
          @method.invokevirtual(
            PrintStream,
            "println",
            [method.return_type, *method.parameter_types])
        else
          log "Could not find a match for #{PrintStream}.println(#{params})"
          fail "Could not compile"
        end
      end

      def return(return_node)
        return_node.value.compile(self, true)

        return_node.inferred_type.return(@method)
      end

      def empty_array(type, size)
        @method.ldc(size)
        type.newarray(@method)
      end
    end
  end
end

if __FILE__ == $0
  Duby::Typer.verbose = true
  Duby::AST.verbose = true
  Duby::Compiler::JVM.verbose = true
  ast = Duby::AST.parse(File.read(ARGV[0]))
  
  typer = Duby::Typer::Simple.new(:script)
  ast.infer(typer)
  typer.resolve(true)
  
  compiler = Duby::Compiler::JVM.new(ARGV[0])
  compiler.compile(ast)
  
  compiler.generate
end
