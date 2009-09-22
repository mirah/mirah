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
        @filename = File.basename(filename)
        @src = ""
        @static = true
        package = File.dirname(filename).tr('/', '.')
        classname = File.basename(filename, '.duby')

        @file = BiteScript::FileBuilder.new(@filename)
        @file.package = package
        @class = @file.public_class(classname)
      end

      def compile(ast, expression = false)
        ast.compile(self, expression)
        log "Compilation successful!"
      end

      def define_main(body)
        with :method => @class.main do
          log "Starting main method"

          @method.start

          # declare argv variable
          @method.local('argv', AST.type('string', true))

          body.compile(self, false)

          @method.returnvoid
          @method.stop
        end

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
          method = @class.public_static_method(name.to_s, return_type, *arg_types)
        else
          if name == "initialize"
            method = @class.public_constructor(*arg_types)
            method.aload 0
            method.invokespecial @method.object, "<init>", [@method.void]
          else
            method = @class.public_method(name.to_s, return_type, *arg_types)
          end
        end

        with :method => method do
          log "Starting new method #{name}(#{arg_types})"

          @method.start

          # declare all args so they get their values
          if args.args
            args.args.each {|arg| @method.local(arg.name, arg.inferred_type)}
          end
        
          expression = signature[:return] != Types::Void
          body.compile(self, expression) if body

          if name == "initialize"
            @method.returnvoid
          else
            signature[:return].return(@method)
          end
        
          @method.stop
        end

        log "Method #{name}(#{arg_types}) complete!"
      end

      def define_class(class_def, expression)
        with(:class => class_def.inferred_type.define(@file),
             :static => false) do
          class_def.body.compile(self, false)
        
          @class.stop
        end
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
        with(:break_label => @method.label,
             :redo_label => @method.label,
             :next_label => @method.label) do
          donelabel = @method.label
          beforelabel = @method.label
        
          # TODO: not checking "check first" or "negative"
          predicate = loop.condition.predicate

          if loop.check_first
            @next_label.set!
            if loop.negative
              # if condition, exit
              jump_if(predicate, @break_label)
            else
              # if not condition, exit
              jump_if_not(predicate, @break_label)
            end
          end
        
          @redo_label.set!
          loop.body.compile(self, expression)
        
          unless loop.check_first
            @next_label.set!
            if loop.negative
              # if not condition, continue
              jump_if_not(predicate, @redo_label)
            else
              # if condition, continue
              jump_if(predicate, @redo_label)
            end
          else
            @method.goto(@next_label)
          end
        
          @break_label.set!
        
          # loops always evaluate to null
          @method.aconst_null if expression
        end
      end
      
      def break
        @method.goto(@break_label)
      end
      
      def next
        @method.goto(@next_label)
      end
      
      def redo
        @method.goto(@redo_label)
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
        type.load(@method, @method.local(name, type))
      end

      def local_assign(name, type, expression)
        declare_local(name, type)
        
        yield
        
        # if expression, dup the value we're assigning
        @method.dup if expression
        
        type.store(@method, @method.local(name, type))
      end

      def declared_locals
        @declared_locals ||= {}
      end

      def declare_local(name, type)
        # TODO confirm types are compatible
        unless declared_locals[name]
          declared_locals[name] = type
          index = @method.local(name, type)
        end
      end

      def local_declare(name, type)
        declare_local(name, type)
        type.init_value(@method)
        type.store(@method, @method.local(name, type))
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
      
      def line(num)
        @method.line(num) if @method
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
        size.compile(self, true)
        type.newarray(@method)
      end
      
      def with(vars)
        orig_values = {}
        begin
          vars.each do |name, new_value|
            name = "@#{name}"
            orig_values[name] = instance_variable_get name
            instance_variable_set name, new_value
          end
          yield
        ensure
          orig_values.each do |name, value|
            instance_variable_set name, value
          end
        end
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
