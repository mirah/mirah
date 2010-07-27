require 'mirah'
require 'duby/jvm/base'
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
    class JVM < JVMCompilerBase
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
          basename = File.basename(filename).sub(/\.(duby|mirah)$/, '')
          basename.split(/_/).map{|x| x[0...1].upcase + x[1..-1]}.join
        end
      end

      module JVMLogger
        def log(message); JVM.log(message); end
      end

      class ImplicitSelf
        attr_reader :inferred_type

        def initialize(type)
          @inferred_type = type
        end

        def compile(compiler, expression)
          compiler.compile_self if expression
        end
      end

      def initialize(filename)
        super
        BiteScript.bytecode_version = BiteScript::JAVA1_5
        @file = BiteScript::FileBuilder.new(@filename)
        AST.type_factory.define_types(@file)
        @jump_scope = []
      end

      def output_type
        "classes"
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

      def begin_main
        # declare argv variable
        @method.local('argv', AST.type('string', true))
      end

      def finish_main
        @method.returnvoid
      end

      def prepare_binding(scope)
        if scope.has_binding?
          type = scope.binding_type
          @binding = @bindings[type]
          @method.new type
          @method.dup
          @method.invokespecial type, "<init>", [@method.void]
          type.store(@method, @method.local('$binding', type))
        end
        begin
          yield
        ensure
          if scope.has_binding?
            @binding.stop
            @binding = nil
          end
        end
      end

      def define_method(node)
        push_jump_scope(node) do
          base_define_method(node, true) do |method, arg_types|
            return if @class.interface?

            log "Starting new #{node.static? ? 'static ' : ''}method #{node.name}(#{arg_types})"
            args = node.arguments.args
            method_body(method, args, node, node.signature[:return])
            log "Method #{node.name}(#{arg_types}) complete!"
          end
        end
      end

      def define_optarg_chain(name, arg, return_type,
                              args_for_opt, arg_types_for_opt)
        # declare all args so they get their values
        @method.aload(0) unless @static
        args_for_opt.each do |req_arg|
          req_arg.inferred_type.load(@method, @method.local(req_arg.name, req_arg.inferred_type))
        end
        arg.children[0].value.compile(self, true)

        # invoke the next one in the chain
        if @static
          @method.invokestatic(@class, name.to_s, [return_type] + arg_types_for_opt + [arg.inferred_type])
        else
          @method.invokevirtual(@class, name.to_s, [return_type] + arg_types_for_opt + [arg.inferred_type])
        end

        return_type.return(@method)
      end

      def constructor(node)
        push_jump_scope(node) do
          super(node, true) do |method, args|
            method_body(method, args, node, Types::Void) do
              method.aload 0
              if node.delegate_args
                if node.calls_super
                  delegate_class = @type.superclass
                else
                  delegate_class = @type
                end
                delegate_types = node.delegate_args.map do |arg|
                  arg.inferred_type
                end
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
      end

      def method_body(method, args, node, return_type)
        body = node.body
        with(:method => method,
             :declared_locals => {}) do

          method.start

          # declare all args so they get their values
          if args
            args.each {|arg| @method.local(arg.name, arg.inferred_type)}
          end
          yield if block_given?

          prepare_binding(node) do
            expression = return_type != Types::Void
            body.compile(self, expression) if body
          end

          return_type.return(@method)

          @method.stop
        end
      end

      def define_closure(class_def, expression)
        compiler = ClosureCompiler.new(@file, @type, self)
        compiler.define_class(class_def, expression)
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
        unless predicate.inferred_type == Types::Boolean
          raise "Expected boolean, found #{predicate.inferred_type}"
        end
        predicate.compile(self, true)
        @method.ifne(target)
      end

      def jump_if_not(predicate, target)
        unless predicate.inferred_type == Types::Boolean
          raise "Expected boolean, found #{predicate.inferred_type}"
        end
        predicate.compile(self, true)
        @method.ifeq(target)
      end

      def call(call, expression)
        return cast(call, expression) if call.cast?
        target = call.target.inferred_type!
        params = call.parameters.map do |param|
          param.inferred_type!
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
        type = fcall.scope.static_scope.self_type
        type = type.meta if (@static && type == @type)
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
        if castee.inferred_type.primitive?
          if fcall.inferred_type.primitive?
            if source_type_name == 'boolean' && target_type_name != "boolean"
              raise TypeError.new "not a boolean type: #{castee.inferred_type}"
            end
            # ok
            primitive = true
          else
            raise TypeError.new "Cannot cast #{castee.inferred_type} to #{fcall.inferred_type}: not a reference type."
          end
        elsif fcall.inferred_type.primitive?
          raise TypeError.new "not a primitive type: #{castee.inferred_type}"
        else
          # ok
          primitive = false
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
        # last element is an expression only if the body is an expression
        super(body, expression) do |last|
          compile(last, expression)
        end
      end

      def local(scope, name, type)
        type.load(@method, @method.local(scoped_local_name(name, scope), type))
      end

      def local_assign(scope, name, type, expression, value)
        declare_local(scope, name, type)

        value.compile(self, true)

        # if expression, dup the value we're assigning
        @method.dup if expression

        type.store(@method, @method.local(scoped_local_name(name, scope), type))
      end

      def declared_locals
        @declared_locals ||= {}
      end

      def annotate(builder, annotations)
        annotations.each do |annotation|
          type = annotation.type
          type = type.jvm_type if type.respond_to?(:jvm_type)
          builder.annotate(type, annotation.runtime?) do |visitor|
            annotation.values.each do |name, value|
              annotation_value(visitor, name, value)
            end
          end
        end
      end

      def annotation_value(builder, name, value)
        case value
        when Duby::AST::Annotation
          type = value.type
          type = type.jvm_type if type.respond_to?(:jvm_type)
          builder.annotation(name, type) do |child|
            value.values.each do |name, value|
              annotation_value(child, name, value)
            end
          end
        when ::Array
          builder.array(name) do |array|
            value.each do |item|
              annotation_value(array, nil, item)
            end
          end
        else
          builder.value(name, value)
        end
      end

      def declare_local(scope, name, type)
        # TODO confirm types are compatible
        name = scoped_local_name(name, scope)
        unless declared_locals[name]
          declared_locals[name] = type
          index = @method.local(name, type)
        end
      end

      def local_declare(scope, name, type)
        declare_local(scope, name, type)
        type.init_value(@method)
        type.store(@method, @method.local(scoped_local_name(name, scope), type))
      end

      def get_binding(type)
        @bindings[type]
      end

      def declared_captures(binding=nil)
        @captured_locals[binding || @binding]
      end

      def captured_local_declare(scope, name, type)
        unless declared_captures[name]
          declared_captures[name] = type
          # default should be fine, but I don't think bitescript supports it.
          @binding.protected_field(name, type)
        end
      end

      def captured_local(scope, name, type)
        captured_local_declare(scope, name, type)
        binding_reference
        @method.getfield(scope.binding_type, name, type)
      end

      def captured_local_assign(node, expression)
        scope, name, type = node.containing_scope, node.name, node.inferred_type
        captured_local_declare(scope, name, type)
        binding_reference
        node.value.compile(self, true)
        @method.dup_x2 if expression
        @method.putfield(scope.binding_type, name, type)
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

      def build_string(nodes, expression)
        if expression
          # could probably be more efficient with non-default constructor
          builder_class = Duby::AST.type('java.lang.StringBuilder')
          @method.new builder_class
          @method.dup
          @method.invokespecial builder_class, "<init>", [@method.void]

          nodes.each do |node|
            node.compile(self, true)
            method = find_method(builder_class, "append", [node.inferred_type], false)
            if method
              @method.invokevirtual builder_class, "append", [method.return_type, *method.argument_types]
            else
              log "Could not find a match for #{java::lang::StringBuilder}.append(#{node.inferred_type})"
              fail "Could not compile"
            end
          end

          # convert to string
          @method.invokevirtual java::lang::StringBuilder.java_class, "toString", [@method.string]
        else
          nodes.each do |node|
            node.compile(self, false)
          end
        end
      end

      def to_string(body, expression)
        if expression
          body.compile(self, true)
          body.inferred_type.box(@method) if body.inferred_type.primitive?
          null = method.label
          done = method.label
          method.dup
          method.ifnull(null)
          @method.invokevirtual @method.object, "toString", [@method.string]
          @method.goto(done)
          null.set!
          method.pop
          method.ldc("null")
          done.set!
        else
          body.compile(self, false)
        end
      end

      def boolean(value)
        value ? @method.iconst_1 : @method.iconst_0
      end

      def regexp(value, flags = 0)
        # TODO: translate flags to Java-appropriate values
        @method.ldc(value)
        @method.invokestatic java::util::regex::Pattern, "compile", [java::util::regex::Pattern, @method.string]
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

      def binding_reference
        @method.aload(@method.local('$binding'))
      end

      def real_self
        method.aload(0)
      end

      def line(num)
        @method.line(num) if @method
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

      def bootstrap_dynamic
        # hacky, I know
        unless defined? @class.bootstrapped
          def @class.bootstrapped; true; end
          method = @class.build_method("<clinit>", :public, :static, [], Java::void)
          method.start
          method.ldc org.jruby.duby.DynalangBootstrap
          method.ldc "bootstrap"
          method.invokestatic java.dyn.Linkage, "registerBootstrapMethod", [method.void, java.lang.Class, method.string]
          method.returnvoid
          method.stop
        end
      end

      class ClosureCompiler < Duby::Compiler::JVM
        def initialize(file, type, parent)
          @file = file
          @type = type
          @jump_scope = []
          @parent = parent
        end

        def prepare_binding(scope)
          if scope.has_binding?
            type = scope.binding_type
            @binding = @parent.get_binding(type)
            @method.aload 0
            @method.getfield(@class, 'binding', @binding)
            type.store(@method, @method.local('$binding', type))
          end
          begin
            yield
          ensure
            if scope.has_binding?
              @binding = nil
            end
          end
        end

        def declared_captures
          @parent.declared_captures(@binding)
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
