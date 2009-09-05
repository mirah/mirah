require 'duby'
require 'duby/jvm/method_lookup'
require 'duby/typer'
require 'duby/plugin/math'
require 'duby/plugin/java'
require 'bitescript'

module Duby
  module Compiler
    class JVM
      import java.lang.System
      import java.io.PrintStream
      include Duby::JVM::MethodLookup
      
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
      
      class MathCompiler
        include JVMLogger
        
        def call(compiler, call, expression)
          call.target.compile(compiler, true)
          call.parameters.each {|param| param.compile(compiler, true)}

          target_type = call.target.inferred_type
          case target_type
          when AST.type(:fixnum)
            case call.name
            when '-'
              compiler.method.isub
            when '+'
              compiler.method.iadd
            when '*'
              compiler.method.imul
            when '/'
              compiler.method.idiv
            when '%'
              compiler.method.irem
            when '<<'
              compiler.method.ishl
            when '>>'
              compiler.method.ishr
            when '>>>'
              compiler.method.iushr
            when '&'
              compiler.method.iand
            when '|'
              compiler.method.ior
            when '^'
              compiler.method.ixor
            else
              raise "Unknown math operation #{call.name} on fixnum"
            end
          when AST.type(:long)
            case call.name
            when '-'
              compiler.method.lsub
            when '+'
              compiler.method.ladd
            when '*'
              compiler.method.lmul
            when '/'
              compiler.method.ldiv
            when '%'
              compiler.method.lrem
            when '<<'
              compiler.method.lshl
            when '>>'
              compiler.method.lshr
            when '>>>'
              compiler.method.lushr
            when '&'
              compiler.method.land
            when '|'
              compiler.method.lor
            when '^'
              compiler.method.lxor
            else
              raise "Unknown math operation #{call.name} on long"
            end
          when AST.type(:float)
            case call.name
            when '-'
              compiler.method.fsub
            when '+'
              compiler.method.fadd
            when '*'
              compiler.method.fmul
            when '/'
              compiler.method.fdiv
            when '%'
              compiler.method.frem
            else
              raise "Unknown math operation #{call.name} on long"
            end
          else
            raise "Unknown math operation #{call.name} on #{target_type}"
          end
          
          # math expressions always return a value, so if we're not an expression we pop the result
          compiler.method.pop unless expression
        end
      end

      class InvokeCompiler
        include JVMLogger
        include Duby::JVM::MethodLookup
        
        def call(compiler, call, expression)
          meta = call.target.inferred_type.meta?
          array = call.target.inferred_type.array?
          
          mapped_target = compiler.mapped_type(call.target.inferred_type)
          mapped_params = call.parameters.map {|param| compiler.mapped_type(param.inferred_type)}

          raise "Invoke attempted on primitive type: #{call.target.inferred_type}" if (mapped_target.primitive?)

          if array
            case call.name
            when "[]"
              raise "Array slicing not yet supported" if mapped_params.size > 1
              raise "Only fixnum array indexing supported" if mapped_params[0] != Java::int.java_class

              call.target.compile(compiler, true)
              call.parameters[0].compile(compiler, true)

              if mapped_target.component_type.primitive?
                case mapped_target.component_type
                when Java::byte.java_class, Java::boolean.java_class
                  compiler.method.baload
                when Java::short.java_class
                  compiler.method.saload
                when Java::char.java_class
                  compiler.method.caload
                when Java::int.java_class
                  compiler.method.iaload
                when Java::long.java_class
                  compiler.method.laload
                when Java::float.java_class
                  compiler.method.faload
                when Java::double.java_class
                  compiler.method.daload
                end
              else
                compiler.method.aaload
              end
            when "[]="
              raise "Array assignment requires an index and a value" if mapped_params.size != 2
              raise "Only fixnum array indexing supported" if mapped_params[0] != Java::int.java_class

              call.target.compile(compiler, true)
              call.parameters[0].compile(compiler, true)
              call.parameters[1].compile(compiler, true)

              if mapped_target.component_type.primitive?
                case mapped_target.component_type
                when Java::byte.java_class, Java::boolean.java_class
                  compiler.method.bastore
                when Java::short.java_class
                  compiler.method.sastore
                when Java::char.java_class
                  compiler.method.castore
                when Java::int.java_class
                  compiler.method.iastore
                when Java::long.java_class
                  compiler.method.lastore
                when Java::float.java_class
                  compiler.method.fastore
                when Java::double.java_class
                  compiler.method.dastore
                end
              else
                compiler.method.aastore
              end
            when "length"
              raise "Array length does not take an argument" if mapped_params.size != 0

              call.target.compile(compiler, true)

              compiler.method.arraylength
            end
          elsif meta
            if call.name == 'new'
              # object construction
              constructor = find_method(mapped_target, call.name, mapped_params, meta)
              compiler.method.new mapped_target
              compiler.method.dup
              call.parameters.each {|param| param.compile(compiler, true)}
              compiler.method.invokespecial(
                mapped_target,
                "<init>",
                [nil, *constructor.parameter_types])
            else
              method = find_method(mapped_target, call.name, mapped_params, meta)
              call.parameters.each {|param| param.compile(compiler, true)}
              compiler.method.invokestatic(
                mapped_target,
                call.name,
                [compiler.mapped_type(call.inferred_type), *method.parameter_types])
              # if expression, void static methods return null, for consistency
              # TODO: inference phase needs to track that signature is void but actual type is null object
              compiler.method.aconst_null if expression && call.inferred_type == AST::TypeReference::NoType
            end
          else
            case call.name
            when '+'
              case call.target.inferred_type
              when AST.type(:string)
                raise "String concat takes one argument" if call.parameters.size != 1
                call.target.compile(compiler, true)
                call.parameters[0].compile(compiler, true)
                compiler.method.invokevirtual(mapped_target, "concat", [compiler.method.string, compiler.method.string])
                return
              end
            end
            method = find_method(mapped_target, call.name, mapped_params, meta)
            call.target.compile(compiler, true)
            
            # if expression, void methods return the called object, for consistency and chaining
            # TODO: inference phase needs to track that signature is void but actual type is callee
            compiler.method.dup if expression && call.inferred_type == AST::TypeReference::NoType
            
            call.parameters.each {|param| param.compile(compiler, true)}
            if mapped_target.interface?
              compiler.method.invokeinterface(
                mapped_target,
                call.name,
                [compiler.mapped_type(call.inferred_type), *method.parameter_types])
            else
              compiler.method.invokevirtual(
                mapped_target,
                call.name,
                [compiler.mapped_type(call.inferred_type), *method.parameter_types])
            end
          end
        end
      end
      
      attr_accessor :filename, :src, :method, :static

      def initialize(filename)
        @filename = filename
        @src = ""
        @static = true

        self.type_mapper[AST.type(:fixnum)] = Java::int.java_class
        self.type_mapper[AST.type(:long)] = Java::long.java_class
        self.type_mapper[AST.type(:float)] = Java::float.java_class
        self.type_mapper[AST.type(:string)] = Java::java.lang.String.java_class
        self.type_mapper[AST.type(:string, true)] = Java::java.lang.String[].java_class
        
        self.call_compilers[AST.type(:fixnum)] =
          self.call_compilers[AST.type(:long)] = MathCompiler.new
          self.call_compilers[AST.type(:float)] = MathCompiler.new
        self.call_compilers.default = InvokeCompiler.new

        @file = BiteScript::FileBuilder.new(filename)
        @class = @file.public_class(filename.split('.')[0])
      end

      def compile(ast, expression = false)
        ast.compile(self, expression)
        log "Compilation successful!"
      end

      def define_main(body)
        oldmethod, @method = @method, @class.public_static_method("main", nil, mapped_type(AST.type(:string, true)))

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
        arg_types = args.args ? args.args.map {|arg| mapped_type(arg.inferred_type)} : []
        if @static
          oldmethod, @method = @method, @class.public_static_method(name.to_s, mapped_type(signature[:return]), *arg_types)
        else
          if name == "initialize"
            oldmethod, @method = @method, @class.public_constructor(*arg_types)
            @method.aload 0
            @method.invokespecial @method.object, "<init>", [@method.void]
          else
            oldmethod, @method = @method, @class.public_method(name.to_s, mapped_type(signature[:return]), *arg_types)
          end
        end

        log "Starting new method #{name}(#{arg_types})"

        @method.start

        # declare all args so they get their values
        args.args.each {|arg| @method.local arg.name} if args.args
        
        expression = signature[:return] != AST.type(:notype)
        body.compile(self, expression)

        if name == "initialize"
          @method.returnvoid
        else
          case signature[:return]
          when AST.type(:notype)
            @method.returnvoid
          when AST.type(:fixnum)
            @method.ireturn
          when AST.type(:boolean)
            @method.ireturn
          when AST.type(:byte)
            @method.ireturn
          when AST.type(:short)
            @method.ireturn
          when AST.type(:char)
            @method.ireturn
          when AST.type(:int)
            @method.ireturn
          when AST.type(:long)
            @method.lreturn
          when AST.type(:float)
            @method.freturn
          when AST.type(:double)
            @method.dreturn
          else
            @method.areturn
          end
        end
        
        @method.stop

        @method = oldmethod

        log "Method #{name}(#{arg_types}) complete!"
      end

      def define_class(class_def, expression)
        prev_class, @class = @class, @file.public_class(class_def.name)
        old_static, @static = @static, false

        type_mapper[AST::type(class_def.name)] = @class
        type_mapper[AST::type(class_def.name, false, true)] = @class
        class_def.body.compile(self, false)
        
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
        case predicate
        when AST::Call
          case predicate.target.inferred_type
          when AST.type(:fixnum)
            # fixnum conditional, so we need to use JVM opcodes
            case predicate.parameters[0].inferred_type
            when AST.type(:fixnum)
              # fixnum on fixnum, easy
              predicate.target.compile(self, true)
              predicate.parameters[0].compile(self, true)
              case predicate.name
              when '<'
                @method.if_icmplt(target)
              when '>'
                @method.if_icmpgt(target)
              when '<='
                @method.if_icmple(target)
              when '>='
                @method.if_icmpge(target)
              when '=='
                @method.if_icmpeq(target)
              else
                raise "Unknown :fixnum on :fixnum predicate operation: " + predicate.name
              end
            else
              raise "Unknown :fixnum on " + predicate.parameters[0].inferred_type + " predicate operations: " + predicate.name
            end
          when AST.type(:float)
            # fixnum conditional, so we need to use JVM opcodes
            case predicate.parameters[0].inferred_type
            when AST.type(:float)
              # fixnum on fixnum, easy
              predicate.target.compile(self, true)
              predicate.parameters[0].compile(self, true)
              case predicate.name
              when '<'
                @method.fcmpl()
                @method.iflt(target)
              when '>'
                @method.fcmpl()
                @method.ifgt(target)
              when '<='
                @method.fcmpl()
                @method.ifle(target)
              when '>='
                @method.fcmpl()
                @method.ifge(target)
              when '=='
                @method.fcmpl()
                @method.ifeq(target)
              else
                raise "Unknown :fixnum on :fixnum predicate operation: " + predicate.name
              end
            else
              raise "Unknown :fixnum on " + predicate.parameters[0].inferred_type + " predicate operations: " + predicate.name
            end
          else
            # try to compile as a normal call
            predicate.compile(self, true)
            @method.ifne(target)
          end
        end
      end
      
      def jump_if_not(predicate, target)
        case predicate
        when AST::Call
          case predicate.target.inferred_type
          when AST.type(:fixnum)
            # fixnum conditional, so we need to use JVM opcodes
            case predicate.parameters[0].inferred_type
            when AST.type(:fixnum)
              # fixnum on fixnum, easy
              predicate.target.compile(self, true)
              predicate.parameters[0].compile(self, true)
              case predicate.name
              when '<'
                @method.if_icmpge(target)
              when '>'
                @method.if_icmple(target)
              when '<='
                @method.if_icmpgt(target)
              when '>='
                @method.if_icmplt(target)
              when '=='
                @method.if_icmpne(target)
              else
                raise "Unknown :fixnum on :fixnum predicate operation: " + predicate.name
              end
            else
              raise "Unknown :fixnum on " + predicate.parameters[0].inferred_type + " predicate operations: " + predicate.name
            end
          when AST.type(:float)
            # fixnum conditional, so we need to use JVM opcodes
            case predicate.parameters[0].inferred_type
            when AST.type(:float)
              # fixnum on fixnum, easy
              predicate.target.compile(self, true)
              predicate.parameters[0].compile(self, true)
              case predicate.name
              when '<'
                @method.fcmpl()
                @method.ifge(target)
              when '>'
                @method.fcmpl()
                @method.ifle(target)
              when '<='
                @method.fcmpl()
                @method.ifgt(target)
              when '>='
                @method.fcmpl()
                @method.iflt(target)
              when '=='
                @method.fcmpl()
                @method.ifne(target)
              else
                raise "Unknown :fixnum on :fixnum predicate operation: " + predicate.name
              end
            else
              raise "Unknown :fixnum on " + predicate.parameters[0].inferred_type + " predicate operations: " + predicate.name
            end
          else
            # try to compile as a normal call
            predicate.compile(self, true)
            @method.ifeq(target)
          end
        end
      end
      
      def call(call, expression)
        call_compilers[call.target.inferred_type].call(self, call, expression)
      end
      
      def call_compilers
        @call_compilers ||= {}
      end
      
      def self_call(fcall, expression)
        fcall.parameters.each {|param| param.compile(self, true)}
        # TODO: self calls for instance methods
        if @static
          @method.invokestatic(
            @method.this,
            fcall.name,
            [mapped_type(fcall.inferred_type), *fcall.parameters.map {|param| mapped_type(param.inferred_type)}])
        else
          @method.invokevirtual(
            @method.this,
            fcall.name,
            [mapped_type(fcall.inferred_type), @fcall.parameters.map {|param| mapped_type(param.inferred_type)}])
        end
        # if expression, we need something on the stack
        if expression
          # if void return...
          if mapped_type(fcall.inferred_type) == Java::void || mapped_type(fcall.inferred_type) == AST::TypeReference::NoType
            # push a null?
            @method.aconst_null
          end
        else
          # if not void return...
          if mapped_type(fcall.inferred_type) != Java::void && mapped_type(fcall.inferred_type) != AST::TypeReference::NoType
            # pop result
            @method.pop
          end
        end
      end
      
      def local(name, type)
        case type
        when AST.type(:fixnum)
          @method.iload(@method.local(name))
        when AST.type(:int)
          @method.iload(@method.local(name))
        when AST.type(:float)
          @method.fload(@method.local(name))
        when AST.type(:long)
          @method.lload(@method.local(name))
        else
          @method.aload(@method.local(name))
        end
      end

      def local_assign(name, type, expression)
        # Handle null specially
        if type == AST::TypeReference::NullType
          @method.aconst_null
          @method.astore(@method.local(name))
          return
        end
        
        real_type = mapped_type(type)
        declare_local(name, real_type)
        
        yield
        
        # if expression, dup the value we're assigning
        @method.dup if expression
        
        case type
        when AST.type(:fixnum)
          @method.istore(@method.local(name))
        when AST.type(:int)
          @method.istore(@method.local(name))
        when AST.type(:float)
          @method.fstore(@method.local(name))
        when AST.type(:long)
          @method.lstore(@method.local(name))
        else
          @method.astore(@method.local(name))
        end
      end

      def declared_locals
        @declared_locals ||= {}
      end

      def declare_local(name, type)
        # TODO confirm types are compatible
        unless declared_locals[name]
          declared_locals[name] = type
          # TODO local variable table for BiteScript
          #@method.local_variable name, type
        end
      end

      def local_declare(name, type)
        real_type = mapped_type(type)
        declare_local(name, real_type)

        case type
        when AST.type(:fixnum)
          @method.push_int(0)
          @method.istore(@method.local(name))
        when AST.type(:int)
          @method.push_int(0)
          @method.istore(@method.local(name))
        when AST.type(:float)
          @method.ldc_float(0.0)
          @method.fstore(@method.local(name))
        when AST.type(:long)
          @method.ldc_long(0)
          @method.lstore(@method.local(name))
        else
          @method.aconst_null
          @method.astore(@method.local(name))
        end
      end

      def field(name, type)
        name = name[1..-1]

        # load self object unless static
        method.aload 0 unless static
        
        real_type = mapped_type(type)

        if static
          @method.getstatic(@class, name, real_type)
        else
          @method.getfield(@class, name, real_type)
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
        real_type = mapped_type(type)
        declare_field(name, real_type)
      end

      def field_assign(name, type, expression)
        name = name[1..-1]

        real_type = declared_fields[name] || mapped_type(type)
        
        # Handle null specially
        if type == AST::TypeReference::NullType
          @method.aload 0 unless static
          @method.aconst_null
          if static
            @method.putstatic(@class, name, real_type)
          else
            @method.putfield(@class, name, real_type)
          end
          return
        end
        
        declare_field(name, real_type)

        if expression
          yield
          @method.dup
          unless static
            method.aload 0
            @method.swap
          end
        else
          method.aload 0 unless static
          yield
        end

        if static
          @method.putstatic(@class, name, real_type)
        else
          @method.putfield(@class, name, real_type)
        end
      end
      
      def fixnum(value)
        @method.push_int(value)
      end

      def float(value)
        @method.ldc_float(value)
      end

      def string(value)
        @method.ldc(value)
      end

      def boolean(value)
        value ? @method.iconst_1 : @method.iconst_0
      end
      
      def newline
        # TODO: line numbering
      end
      
      def generate
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
      
      def type_mapper
        @type_mapper ||= {}
      end

      def mapped_type(type)
        return Java::void if type == AST::TypeReference::NoType
        return Java::java.lang.Object.java_class if type == AST::TypeReference::NullType
        return type_mapper[type] if type_mapper[type]
        if type.array?
          Java::JavaClass.for_name(type.name).array_class
        else
          Java::JavaClass.for_name(type.name)
        end
      end

      def import(short, long)
        # TODO hacky..we map both versions because some get expanded during inference
        # TODO hacky again..meta and non-meta
        type_mapper[AST::type(short, false, true)] = Java::JavaClass.for_name(long)
        type_mapper[AST::type(long, false, true)] = Java::JavaClass.for_name(long)
        type_mapper[AST::type(short, false, false)] = Java::JavaClass.for_name(long)
        type_mapper[AST::type(long, false, false)] = Java::JavaClass.for_name(long)
      end

      def println(printline)
        @method.getstatic System, "out", PrintStream
        printline.parameters.each {|param| param.compile(self, true)}
        mapped_params = printline.parameters.map {|param| mapped_type(param.inferred_type)}
        method = find_method(PrintStream.java_class, "println", mapped_params, false)
        if (method)
          @method.invokevirtual(
            PrintStream,
            "println",
            [method.return_type, *method.parameter_types])
        else
          log "Could not find a match for #{PrintStream}.println(#{mapped_params})"
          fail "Could not compile"
        end
      end

      def return(return_node)
        return_node.value.compile(self, true)

        case return_node.inferred_type
        when AST.type(:fixnum)
          @method.ireturn
        when AST.type(:int)
          @method.ireturn
        when AST.type(:float)
          @method.freturn
        when AST.type(:long)
          @method.lreturn
        else
          @method.areturn
        end
      end

      def empty_array(type, size)
        case type
        when AST.type(:fixnum)
          @method.ldc(size)
          @method.newintarray
        when AST.type(:boolean)
          @method.ldc(size)
          @method.newbooleanarray
        when AST.type(:byte)
          @method.ldc(size)
          @method.newbytearray
        when AST.type(:short)
          @method.ldc(size)
          @method.newshortarray
        when AST.type(:char)
          @method.ldc(size)
          @method.newchararray
        when AST.type(:int)
          @method.ldc(size)
          @method.newintarray
        when AST.type(:long)
          @method.ldc(size)
          @method.newlongarray
        when AST.type(:float)
          @method.ldc(size)
          @method.newfloatarray
        when AST.type(:double)
          @method.ldc(size)
          @method.newdoublearray
        else
          @method.ldc(size)
          @method.anewarray mapped_type(type).java_class
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
