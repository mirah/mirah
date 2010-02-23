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

    class Super
      attr_accessor :target
    end
  end
  
  module Compiler
    class JVM
      java_import java.lang.System
      java_import java.io.PrintStream
      include Duby::JVM::MethodLookup
      Types = Duby::JVM::Types

      class << self
        attr_accessor :verbose

        def log(message)
          puts "* [#{name}] #{message}" if JVM.verbose
        end

        def classname_from_filename(filename)
          basename = File.basename(filename, '.duby')
          basename.split(/_/).map{|x| x[0...1].upcase + x[1..-1]}.join
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
          compiler.compile_self if expression
        end
      end
      
      attr_accessor :filename, :src, :method, :static, :class

      def initialize(filename)
        @filename = File.basename(filename)
        @src = ""
        @static = true
        classname = JVM.classname_from_filename(filename)
        BiteScript.bytecode_version = BiteScript::JAVA1_5
        @file = BiteScript::FileBuilder.new(@filename)
        AST.type_factory.define_types(@file)
        @type = AST::type(classname)
        @jump_scope = []
      end

      def compile(ast, expression = false)
        ast.compile(self, expression)
        log "Compilation successful!"
      end

      def toplevel_class
        @class = @type.define(@file)
      end

      def push_jump_scope(node)
        raise "Not a node" unless Duby::AST::Node === node
        begin
          @jump_scope << node
          yield
        ensure
          @jump_scope.pop
        end
      end
      
      def find_ensures(before)
        found = []
        @jump_scope.reverse_each do |scope|
          if Duby::AST::Ensure === scope
            found << scope
          end
          break if scope === before
        end
        found
      end

      def define_main(body)
        body = body[0] if body.children.size == 1
        if body.class != AST::ClassDefinition
          @class = @type.define(@file)
          with :method => @class.main do
            log "Starting main method"

            @method.start

            # declare argv variable
            @method.local('argv', AST.type('string', true))

            body.compile(self, false)

            @method.returnvoid
            @method.stop
          end
          @class.stop
        else
          body.compile(self, false)
        end

        log "Main method complete!"
      end
      
      def define_method(node)
        push_jump_scope(node) do
          name, signature, args = node.name, node.signature, node.arguments.args
          arg_types = if args
            args.map { |arg| arg.inferred_type }
          else
            []
          end
          return_type = signature[:return]
          exceptions = signature[:throws]

          with :static => @static || node.static? do
            if @static
              method = @class.public_static_method(name.to_s, exceptions, return_type, *arg_types)
            else
              method = @class.public_method(name.to_s, exceptions, return_type, *arg_types)
            end

            annotate(method, node.annotations)

            return if @class.interface?

            log "Starting new method #{name}(#{arg_types})"
            method_body(method, args, node.body, signature[:return])

            arg_types_for_opt = []
            args_for_opt = []
            if args
              args.each do |arg|
                if AST::OptionalArgument === arg
                  if @static
                    method = @class.public_static_method(name.to_s, exceptions, return_type, *arg_types_for_opt)
                  else
                    method = @class.public_method(name.to_s, exceptions, return_type, *arg_types_for_opt)
                  end

                  with :method => method do
                    log "Starting new method #{name}(#{arg_types_for_opt})"

                    @method.start

                    # declare all args so they get their values
                    @method.aload(0) unless @static
                    args_for_opt.each do |req_arg|
                      req_arg.inferred_type.load(@method, @method.local(req_arg.name, req_arg.inferred_type))
                    end
                    arg.children[0].compile(self, true)

                    # invoke the next one in the chain
                    if @static
                      @method.invokestatic(@class, name.to_s, [return_type] + arg_types_for_opt + [arg.inferred_type])
                    else
                      @method.invokevirtual(@class, name.to_s, [return_type] + arg_types_for_opt + [arg.inferred_type])
                    end

                    signature[:return].return(@method)

                    @method.stop
                  end
                end
                arg_types_for_opt << arg.inferred_type
                args_for_opt << arg
              end
            end
          end

          log "Method #{name}(#{arg_types}) complete!"        end
      end
      
      def constructor(node)
        push_jump_scope(node) do
          args = node.arguments.args || []
          arg_types = args.map { |arg| arg.inferred_type }
          exceptions = node.signature[:throws]
          method = @class.public_constructor(exceptions, *arg_types)
          annotate(method, node.annotations)
          method_body(method, args, node.body, Types::Void) do
            method.aload 0
            if node.delegate_args
              if node.calls_super
                delegate_class = @type.superclass
              else
                delegate_class = @type
              end
              delegate_types = node.delegate_args.map {|arg| arg.inferred_type}
              constructor = delegate_class.constructor(*delegate_types)
              node.delegate_args.each do |arg|
                arg.compile(self, true)
              end
              method.invokespecial(
                  delegate_class, "<init>",
                  [@method.void, *constructor.argument_types])
            else
              method.invokespecial @class.superclass, "<init>", [@method.void]
            end
          end
        end
      end

      def method_body(method, args, body, return_type)
        with :method => method do

          method.start

          # declare all args so they get their values
          if args
            args.each {|arg| @method.local(arg.name, arg.inferred_type)}
          end

          yield if block_given?

          expression = return_type != Types::Void
          body.compile(self, expression) if body

          return_type.return(@method)
        
          @method.stop
        end
      end

      def define_class(class_def, expression)
        with(:type => class_def.inferred_type,
             :class => class_def.inferred_type.define(@file),
             :static => false) do
          annotate(@class, class_def.annotations)
          class_def.body.compile(self, false) if class_def.body
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
        if iff.body || expression
          jump_if_not(predicate, elselabel)

          if iff.body
            iff.body.compile(self, expression)
          elsif expression
            iff.inferred_type.init_value(@method)
          end

          @method.goto(donelabel)
        else
          jump_if(predicate, donelabel)
        end

        elselabel.set!

        if iff.else
          iff.else.compile(self, expression)
        elsif expression
          iff.inferred_type.init_value(@method)
        end

        donelabel.set!
      end

      def loop(loop, expression)
        push_jump_scope(loop) do
          with(:break_label => @method.label,
               :redo_label => @method.label,
               :next_label => @method.label) do
            predicate = loop.condition.predicate

            loop.init.compile(self, false) if loop.init?

            pre_label = @redo_label

            if loop.check_first
              @next_label.set! unless loop.post?
              if loop.negative
                # if condition, exit
                jump_if(predicate, @break_label)
              else
                # if not condition, exit
                jump_if_not(predicate, @break_label)
              end
            end

            if loop.pre?
              pre_label = method.label
              pre_label.set!
              loop.pre.compile(self, false)
            end


            @redo_label.set!
            loop.body.compile(self, false)
        
            if loop.check_first && !loop.post?
              @method.goto(@next_label)
            else
              @next_label.set!
              loop.post.compile(self, false) if loop.post?
              if loop.negative
                # if not condition, continue
                jump_if_not(predicate, pre_label)
              else
                # if condition, continue
                jump_if(predicate, pre_label)
              end
            end
        
            @break_label.set!
        
            # loops always evaluate to null
            @method.aconst_null if expression
          end
        end
      end

      def break(node)
        handle_ensures(find_ensures(Duby::AST::Loop))
        @method.goto(@break_label)
      end
      
      def next(node)
        handle_ensures(find_ensures(Duby::AST::Loop))
        @method.goto(@next_label)
      end
      
      def redo(node)
        handle_ensures(find_ensures(Duby::AST::Loop))
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
        return cast(fcall, expression) if fcall.cast?
        type = @type
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

      def super_call(sup, expression)
        type = @type.superclass
        sup.target = ImplicitSelf.new(type)

        params = sup.parameters.map do |param|
          param.inferred_type
        end
        method = type.get_method(sup.name, params)
        unless method

          raise NameError, "No method %s.%s(%s)" %
              [type, sup.name, params.join(', ')]
        end
        method.call_special(self, sup, expression)
      end

      def cast(fcall, expression)
        # casting operation, not a call
        castee = fcall.parameters[0]
        
        # TODO move errors to inference phase
        source_type_name = castee.inferred_type.name
        target_type_name = fcall.inferred_type.name
        case source_type_name
        when "byte", "short", "char", "int", "long", "float", "double"
          case target_type_name
          when "byte", "short", "char", "int", "long", "float", "double"
            # ok
            primitive = true
          else
            raise TypeError.new "not a reference type: #{castee.inferred_type}"
          end
        when "boolean"
          if target_type_name != "boolean"
            raise TypeError.new "not a boolean type: #{castee.inferred_type}"
          end
          primitive = true
        else
          case target_type_name
          when "byte", "short", "char", "int", "long", "float", "double"
            raise TypeError.new "not a primitive type: #{castee.inferred_type}"
          else
            # ok
            primitive = false
          end
        end

        castee.compile(self, expression)
        if expression
          if primitive
            source_type_name = 'int' if %w[byte short char].include? source_type_name
            if (source_type_name != 'int') && (%w[byte short char].include? target_type_name)
              target_type_name = 'int'
            end

            if source_type_name != target_type_name
              if RUBY_VERSION == "1.9"
                @method.send "#{source_type_name[0]}2#{target_type_name[0]}"
              else
                @method.send "#{source_type_name[0].chr}2#{target_type_name[0].chr}"
              end
            end
          else
            if source_type_name != target_type_name
              @method.checkcast fcall.inferred_type
            end
          end
        end
      end
      
      def body(body, expression)
        # all except the last element in a body of code is treated as a statement
        i, last = 0, body.children.size - 1
        while i < last
          body.children[i].compile(self, false)
          i += 1
        end
        # last element is an expression only if the body is an expression
        body.children[last].compile(self, expression) if last >= 0
      end
      
      def local(name, type)
        type.load(@method, @method.local(name, type))
      end

      def local_assign(name, type, expression, value)
        declare_local(name, type)
        
        value.compile(self, true)
        
        # if expression, dup the value we're assigning
        @method.dup if expression
        
        type.store(@method, @method.local(name, type))
      end

      def declared_locals
        @declared_locals ||= {}
      end

      def annotate(builder, annotations)
        annotations.each do |annotation|
          builder.annotate(annotation.type.jvm_type) do |visitor|
            # todo values
          end
        end
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

      def field(name, type, annotations)
        name = name[1..-1]

        real_type = declared_fields[name] || type

        declare_field(name, real_type, annotations)

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
        @declared_fields[@class] ||= {}
      end

      def declare_field(name, type, annotations)
        # TODO confirm types are compatible
        unless declared_fields[name]
          declared_fields[name] = type
          field = if static
            @class.private_static_field name, type
          else
            @class.private_field name, type
          end
          annotate(field, annotations)
        end
      end

      def field_declare(name, type, annotations)
        name = name[1..-1]
        declare_field(name, type, annotations)
      end

      def field_assign(name, type, expression, value, annotations)
        name = name[1..-1]

        real_type = declared_fields[name] || type
        
        declare_field(name, real_type, annotations)

        method.aload 0 unless static
        value.compile(self, true)
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

      def array(node, expression)
        if expression
          # create basic arraylist
          @method.new java::util::ArrayList
          @method.dup
          @method.ldc_int node.children ? node.children.size : 0
          @method.invokespecial java::util::ArrayList, "<init>", [@method.void, @method.int]

          # elements, as expressions
          # TODO: ensure they're all reference types!
          node.children.each do |n|
            @method.dup
            n.compile(self, true)
            # TODO this feels like it should be in the node.compile itself
            if n.inferred_type.primitive?
              n.inferred_type.box(@method)
            end
            @method.invokeinterface java::util::List, "add", [@method.boolean, @method.object]
            @method.pop
          end

          # make it unmodifiable
          @method.invokestatic java::util::Collections, "unmodifiableList", [java::util::List, java::util::List]
        else
          # elements, as non-expressions
          # TODO: ensure they're all reference types!
          node.children.each do |n|
            n.compile(self, true)
            # TODO this feels like it should be in the node.compile itself
            if n.inferred_type.primitive?
              n.inferred_type.box(@method)
            end
          end
        end
      end
      
      def null
        @method.aconst_null
      end
      
      def compile_self
        method.aload(0)
      end
      
      def newline
        # TODO: line numbering
      end
      
      def line(num)
        @method.line(num) if @method
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
      
      def import(short, long)
      end

      def print(print_node)
        @method.getstatic System, "out", PrintStream
        print_node.parameters.each {|param| param.compile(self, true)}
        params = print_node.parameters.map {|param| param.inferred_type.jvm_type}
        method_name = print_node.println ? "println" : "print"
        method = find_method(PrintStream.java_class, method_name, params, false)
        if (method)
          @method.invokevirtual(
            PrintStream,
            method_name,
            [method.return_type, *method.parameter_types])
        else
          log "Could not find a match for #{PrintStream}.#{method_name}(#{params})"
          fail "Could not compile"
        end
      end

      def return(return_node)
        return_node.value.compile(self, true)
        handle_ensures(find_ensures(Duby::AST::MethodDefinition))
        return_node.inferred_type.return(@method)
      end

      def _raise(exception)
        exception.compile(self, true)
        @method.athrow
      end
      
      def rescue(rescue_node, expression)
        start = @method.label.set!
        body_end = @method.label
        done = @method.label
        rescue_node.body.compile(self, expression)
        body_end.set!
        @method.goto(done)
        rescue_node.clauses.each do |clause|
          target = @method.label.set!
          if clause.name
            @method.astore(@method.push_local(clause.name, clause.type))
          else
            @method.pop
          end
          clause.body.compile(self, expression)
          @method.pop_local(clause.name) if clause.name
          @method.goto(done)
          clause.types.each do |type|
            @method.trycatch(start, body_end, target, type)
          end
        end
        done.set!
      end

      def handle_ensures(nodes)
        nodes.each do |ensure_node|
          ensure_node.clause.compile(self, false)
        end
      end

      def ensure(node, expression)
        node.state = @method.label  # Save the ensure target for JumpNodes
        start = @method.label.set!
        body_end = @method.label
        done = @method.label
        push_jump_scope(node) do
          node.body.compile(self, expression)  # First compile the body
        end
        body_end.set!
        handle_ensures([node])  # run the ensure clause
        @method.goto(done)  # and continue on after the exception handler
        target = @method.label.set!  # Finally, create the exception handler
        @method.trycatch(start, body_end, target, nil)
        handle_ensures([node])
        @method.athrow
        done.set!
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
