module Mirah
  module JVM
    module Compiler
      class JVMBytecode < Base
        java_import java.lang.System
        java_import java.io.PrintStream
        include Mirah::JVM::MethodLookup
        include Mirah::Logging::Logged
        Types = Mirah::JVM::Types
        java_import 'mirah.lang.ast.Node'
        java_import 'mirah.lang.ast.Array'
        java_import 'mirah.lang.ast.Annotation'
        java_import 'mirah.lang.ast.MethodDefinition'
        java_import 'mirah.lang.ast.ConstructorDefinition'
        java_import 'mirah.lang.ast.Ensure'
        java_import 'mirah.lang.ast.Call'
        java_import 'mirah.lang.ast.Loop'
        java_import 'mirah.lang.ast.FunctionalCall'
        java_import 'mirah.lang.ast.Super'
        java_import 'mirah.lang.ast.ZSuper'
        java_import 'mirah.lang.ast.ImplicitSelf'
        java_import 'mirah.lang.ast.NodeList'
        java_import 'mirah.lang.ast.SimpleString'
        java_import 'mirah.lang.ast.StringConcat'
        java_import 'org.mirah.typer.TypeFuture'

        class FunctionalCall
          attr_accessor :target
        end
        class Super
          attr_accessor :target, :name
        end

        class << self
          attr_accessor :verbose

          def classname_from_filename(filename)
            basename = File.basename(filename).sub(/\.(duby|mirah)$/, '')
            basename.split(/[_-]/).map{|x| x[0...1].upcase + x[1..-1]}.join
          end
        end

        def initialize(scoper, typer)
          super
          @jump_scope = []
        end

        def logger_name
          "org.mirah.ruby.JVM.Compiler.JVMBytecode"
        end

        def file_builder(filename)
          builder = BiteScript::FileBuilder.new(filename)
          builder.to_widen do |_a, _b|
            a = @typer.type_system.get_type(_a)
            b = @typer.type_system.get_type(_b)
            a_ancestors = []
            while a
              a_ancestors << a.name
              a = a.superclass
            end
            b_ancestors = []
            while b
              b_ancestors << b.name
              b = b.superclass
            end
            intersection = (a_ancestors & b_ancestors)
            intersection[0].gsub('.', '/')
          end
          @typer.type_system.define_types(builder)
          builder
        end

        def output_type
          "classes"
        end

        def push_jump_scope(node)
          raise "Not a node" unless Node === node
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
            if Ensure === scope
              found << scope
            end
            break if before === scope
          end
          found
        end

        def begin_main
          # declare argv variable
          @method.local('argv', @typer.type_system.type(nil, 'string', true))
        end

        def finish_main
          @method.returnvoid
        end

        def prepare_binding(node)
          scope = introduced_scope(node)
          if scope.has_binding?
            type = scope.binding_type
            @binding = @bindings[type]
            @method.new type
            @method.dup
            @method.invokespecial type, "<init>", [@method.void]
            if node.respond_to? :arguments
              node.arguments.required.each do |param|
                name = param.name.identifier
                param_type = inferred_type(param)
                if scope.captured?(param.name.identifier)
                  @method.dup
                  type.load(@method, @method.local(name, param_type))
                  @method.putfield(type, name, param_type)
                end
              end
            end
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

        def visitMethodDefinition(node, expression)
          push_jump_scope(node) do
            base_define_method(node) do |method, arg_types|
              return if @class.interface?
              is_static = self.static || node.kind_of?(StaticMethodDefinition)

              log "Starting new #{is_static ? 'static ' : ''}method #{node.name.identifier}(#{arg_types})"
              args = visit(node.arguments, true)
              method_body(method, args, node, inferred_type(node).returnType)
              log "Method #{node.name.identifier}(#{arg_types}) complete!"
            end
          end
        end

        def define_optarg_chain(name, arg, return_type,
          args_for_opt, arg_types_for_opt)
          # declare all args so they get their values
          @method.aload(0) unless @static
          args_for_opt.each do |req_arg|
            inferred_type(req_arg).load(@method, @method.local(req_arg.name.identifier, inferred_type(req_arg)))
          end
          visit(arg.value, true)

          # invoke the next one in the chain
          if @static
            @method.invokestatic(@class, name.to_s, [return_type] + arg_types_for_opt + [inferred_type(arg)])
          else
            @method.invokevirtual(@class, name.to_s, [return_type] + arg_types_for_opt + [inferred_type(arg)])
          end

          return_type.return(@method)
        end

        def visitConstructorDefinition(node, expression)
          push_jump_scope(node) do
            super(node, true) do |method, args|
              method_body(method, args, node, @typer.type_system.type(nil, 'void')) do
                method.aload 0
                scope = introduced_scope(node)
                if node.body.size > 0 &&
                    (node.body(0).kind_of?(Super) || node.body(0).kind_of?(ZSuper))
                  super_node = node.body(0)
                  delegate_class = @type.superclass
                  delegate_types = []
                  if super_node.kind_of?(ZSuper)
                    [node.arguments.required,
                     node.arguments.optional,
                     node.arguments.required2
                    ].each do |args|
                      args.each do |arg|
                        arg_type = inferred_type(arg)
                        delegate_types << arg_type
                        local(scope, arg.name.identifier, arg_type)
                      end
                    end
                  else
                    super_node.parameters.each do |param|
                      param_type = inferred_type(param)
                      delegate_types << param_type
                      visit(param, true)
                    end
                  end
                  constructor = delegate_class.constructor(*delegate_types)
                  method.invokespecial(
                  delegate_class, "<init>",
                  [@method.void, *constructor.argument_types])
                else
                  unless (node.body.size > 0 &&
                          node.body(0).kind_of?(FunctionalCall) &&
                          node.body(0).name.identifier == 'initialize')
                    method.invokespecial @class.superclass, "<init>", [@method.void]
                  end
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

            scope = introduced_scope(node)

            # declare all args so they get their values
            if args
              args.each {|arg| declare_local(scope, arg.name.identifier, inferred_type(arg))}
            end
            declare_locals(scope)

            yield if block_given?

            prepare_binding(node) do
              expression = return_type.name != 'void'
              visit(body, expression) if body
            end

            return_type.return(@method)

            @method.stop
          end
        end

        def visitClosureDefinition(class_def, expression)
          compiler = ClosureCompiler.new(@file, @type, self, @scoper, @typer)
          compiler.visitClassDefinition(class_def, expression)
        end

        def visitInterfaceDeclaration(class_def, expression)
          visitClassDefinition(class_def, expression)
        end

        def visitIf(iff, expression)
          elselabel = @method.label
          donelabel = @method.label

          # this is ugly...need a better way to abstract the idea of compiling a
          # conditional branch while still fitting into JVM opcodes
          predicate = iff.condition
          body = iff.body
          elseBody = iff.elseBody
          if body.is_a?(NodeList) && body.size == 0
            body = nil
          end
          if elseBody.is_a?(NodeList) && elseBody.size == 0
            elseBody = nil
          end
          if body || expression
            jump_if_not(predicate, elselabel)

            if body
              visit(body, expression)
            elsif expression
              inferred_type(iff).init_value(@method)
            end

            @method.goto(donelabel)
          else
            jump_if(predicate, donelabel)
          end

          elselabel.set!

          if elseBody
            visit(elseBody, expression)
          elsif expression
            inferred_type(iff).init_value(@method)
          end

          donelabel.set!
        end

        def visitLoop(loop, expression)
          push_jump_scope(loop) do
            with(:break_label => @method.label,
                 :redo_label => @method.label,
                 :next_label => @method.label) do
              predicate = loop.condition

              visit(loop.init, false)

              pre_label = @redo_label

              unless loop.skipFirstCheck
                @next_label.set! unless loop.post_size > 0
                if loop.negative
                  # if condition, exit
                  jump_if(predicate, @break_label)
                else
                  # if not condition, exit
                  jump_if_not(predicate, @break_label)
                end
              end

              if loop.pre_size > 0
                pre_label = method.label
                pre_label.set!
                visit(loop.pre, false)
              end


              @redo_label.set!
              visit(loop.body, false) if loop.body

              if loop.skipFirstCheck || loop.post_size > 0
                @next_label.set!
                visit(loop.post, false)
                if loop.negative
                  # if not condition, continue
                  jump_if_not(predicate, pre_label)
                else
                  # if condition, continue
                  jump_if(predicate, pre_label)
                end
              else
                @method.goto(@next_label)
              end

              @break_label.set!

              # loops always evaluate to null
              @method.aconst_null if expression
            end
          end
        end

        def visitBreak(node, expression)
          error("break outside of loop", node) unless @break_label
          handle_ensures(find_ensures(Loop))
          set_position node.position
          @method.goto(@break_label)
        end

        def visitNext(node, expression)
          error("next outside of loop", node) unless @next_label
          handle_ensures(find_ensures(Loop))
          set_position node.position
          @method.goto(@next_label)
        end

        def visitRedo(node, expression)
          error("redo outside of loop", node) unless @redo_label
          handle_ensures(find_ensures(Loop))
          set_position node.position
          @method.goto(@redo_label)
        end

        def jump_if(predicate, target)
          type = inferred_type(predicate)
          if type.primitive?
            raise "Expected boolean, found #{type}" unless type.name == 'boolean'
          end
          if Call === predicate
            method = extract_method(predicate)
            if method.respond_to? :jump_if
              method.jump_if(self, predicate, target)
              return
            end
          end
          visit(predicate, true)
          if type.primitive?
            @method.ifne(target)
          else
            @method.ifnonnull(target)
          end
        end

        def jump_if_not(predicate, target)
          type = inferred_type(predicate)
          if type.primitive?
            raise "Expected boolean, found #{type}" unless type.name == 'boolean'
          end
          if Call === predicate
            method = extract_method(predicate)
            if method.respond_to? :jump_if_not
              method.jump_if_not(self, predicate, target)
              return
            end
          end
          visit(predicate, true)
          if type.primitive?
            @method.ifeq(target)
          else
            @method.ifnull(target)
          end
        end

        def extract_method(call)
          target = inferred_type(call.target)
          params = call.parameters.map do |param|
            inferred_type(param)
          end
          target.get_method(call.name.identifier, params)
        end

        def visitAttrAssign(call, expression)
          target = inferred_type(call.target)
          value_type = inferred_type(call.value)
          setter = "#{call.name.identifier}_set"
          method = target.get_method(setter, [value_type])
          if method
            method.call(self, call, expression, [call.value])
          else
            target = inferred_type(call.target)
            raise "Missing method #{target.full_name}.#{setter}(#{value_type.full_name})"
          end
        end

        def visitCall(call, expression)
          method = extract_method(call)
          if method
            method.call(self, call, expression)
          else
            params = call.parameters.map do |param|
              inferred_type(param)
            end
            target = inferred_type(call.target)
            raise "Missing method #{target}.#{call.name.identifier}(#{params.join ', '})"
          end
        end

        def visitFunctionalCall(fcall, expression)
          scope = get_scope(fcall)
          type = get_scope(fcall).self_type.resolve
          type = type.meta if (@static && type == @type)
          fcall.target = ImplicitSelf.new
          fcall.target.parent = fcall
          @typer.infer(fcall.target)

          params = fcall.parameters.map do |param|
            inferred_type(param)
          end
          name = fcall.name.identifier
          chained_constructor = false
          if name == 'initialize'
            if scope.context.kind_of?(ConstructorDefinition) &&
                scope.context.body(0) == fcall
              name = '<init>'
              chained_constructor = true
            end
          end

          method = type.get_method(name, params)
          unless method
            target = static ? @class.name : 'self'

            raise NameError, "No method %s.%s(%s)" %
            [target, fcall.name.identifier, params.join(', ')]
          end
          if chained_constructor
            method.call(self, fcall, expression, nil, true)
          else
            method.call(self, fcall, expression)
          end
        end

        def visitSuper(sup, expression)
          mdef = sup.findAncestor(MethodDefinition.java_class)
          # FIXME Horrible hack
          return if mdef.kind_of?(ConstructorDefinition)
          type = @type.superclass
          super_type = @typer.type_system.getSuperClass(get_scope(sup).self_type)
          @typer.infer(sup.target)

          sup.name = mdef.name.identifier

          # TODO ZSuper
          params = sup.parameters.map do |param|
            inferred_type(param)
          end
          method = type.get_method(sup.name, params)
          unless method
            raise NameError, "No method %s.%s(%s)" %
            [type, sup.name, params.join(', ')]
          end
          method.call_special(self, ImplicitSelf.new, type, sup.parameters, expression)
        end

        def visitCast(fcall, expression)
          # casting operation, not a call
          castee = fcall.value

          # TODO move errors to inference phase
          source_type_name = inferred_type(castee).name
          target_type_name = inferred_type(fcall).name
          if inferred_type(castee).primitive?
            if inferred_type(fcall).primitive?
              if source_type_name == 'boolean' && target_type_name != "boolean"
                raise TypeError.new "not a boolean type: #{inferred_type(castee)}"
              end
              # ok
              primitive = true
            else
              raise TypeError.new "Cannot cast #{inferred_type(castee)} to #{inferred_type(fcall)}: not a reference type."
            end
          elsif inferred_type(fcall).primitive?
            raise TypeError.new "not a primitive type: #{inferred_type(castee)}"
          else
            # ok
            primitive = false
          end

          visit(castee, expression)
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
              if (source_type_name != target_type_name ||
                inferred_type(castee).array? != inferred_type(fcall).array?)
                @method.checkcast inferred_type(fcall)
              end
            end
          end
        end

        def visitNodeList(body, expression)
          # last element is an expression only if the body is an expression
          super(body, expression) do |last|
            if last
              visit(last, expression)
            elsif expression
              inferred_type(body).init_value(method)
            end
          end
        end

        def declared_locals
          @declared_locals ||= {}
        end

        def annotate(builder, annotations)
          annotations.each do |annotation|
            type = inferred_type(annotation)
            mirror = type.jvm_type
            if mirror.respond_to?(:getDeclaredAnnotation)
              retention = mirror.getDeclaredAnnotation('java.lang.annotation.Retention')
            else
              raise "Unsupported annotation #{mirror} (#{mirror.class})"
            end
            next if retention && retention.value.name == 'SOURCE'
            runtime_retention = (retention && retention.value.name == 'RUNTIME')
            builder.annotate(mirror, runtime_retention) do |visitor|
              annotation.values.each do |entry|
                annotation_value(get_scope(annotation), type, visitor,
                                 entry.key.identifier, entry.value)
              end
            end
          end
        end

        def annotation_value(scope, type, builder, name, value)
          if name
            value_type = type.unmeta.java_method(name).return_type
            if value_type.array?
              unless value.kind_of?(Array)
                raise "#{type.name}.#{name} should be an Array, got #{value.class}"
              end
              builder.array(name) do |child|
                value.values.each do |item|
                  annotation_value(scope, value_type.component_type, child, nil, item)
                end
              end
              return
            end
          else
            value_type = type
          end
          primitive_classes = {
            'Z' => java.lang.Boolean,
            'B' => java.lang.Byte,
            'C' => java.lang.Character,
            'S' => java.lang.Short,
            'I' => java.lang.Integer,
            'J' => java.lang.Long,
            'F' => java.lang.Float,
            'D' => java.lang.Double,
          }
          descriptor = BiteScript::Signature::class_id(value_type)
          case descriptor
          when 'Ljava/lang/String;'
            string_value = if value.kind_of?(StringConcat)
              value.strings.map {|x| x.identifier}.join
            else
              value.identifier
            end
            builder.visit(name, string_value)
          when 'Ljava/lang/Class;'
            mirror = @typer.type_system.type(scope, value.typeref.name)
            klass = if value.typeref.isArray
              BiteScript::ASM::Type.get("[#{mirror.type.descriptor}")
            else
              mirror
            end
            builder.visit(name, klass)
          when *primitive_classes.keys
            klass = primitive_classes[descriptor]
            builder.visit(name, klass.new(value.value))
          else
            if value_type.jvm_type.enum?
              builder.enum(name, value_type, value.identifier)
            elsif value_type.jvm_type.annotation?
              subtype = inferred_type(value)
              mirror = subtype.jvm_type
              builder.annotation(name, mirror) do |child|
                value.values.each do |entry|
                  annotation_value(scope, subtype, child, entry.key.identifier, entry.value)
                end
              end
            else
              raise "Unsupported annotation #{descriptor} #{name} = #{value.class}"
            end
          end
        end

        def declared?(scope, name)
          declared_locals.include?(scoped_local_name(name, scope))
        end

        def declare_local(scope, name, type)
          # TODO confirm types are compatible
          name = scoped_local_name(name, scope)
          unless declared_locals[name]
            declared_locals[name] = type
            index = @method.local(name, type)
          end
        end

        def declare_locals(scope)
          scope.locals.each do |name|
            unless scope.captured?(name) || declared?(scope, name)
              type = scope.local_type(name)
              type = type.resolve if type.kind_of?(TypeFuture)
              declare_local(scope, name, type)
              type.init_value(@method)
              type.store(@method, @method.local(scoped_local_name(name, scope), type))
            end
          end
        end

        def get_binding(type)
          @bindings[type]
        end

        def declared_captures(binding=nil)
          @captured_locals[binding || @binding]
        end

        def visitLocalDeclaration(local, expression)
          scope = get_scope(local)
          if scope.has_binding? && scope.captured?(local.name.identifier)
            captured_local_declare(scope, local.name.identifier, inferred_type(local))
          end
        end

        def captured_local_declare(scope, name, type)
          unless declared_captures[name]
            declared_captures[name] = type
            # default should be fine, but I don't think bitescript supports it.
            @binding.protected_field(name, type)
          end
        end

        def visitLocalAccess(local, expression)
          if expression
            set_position(local.position)
            scope = get_scope(local)
            if scope.has_binding? && scope.captured?(local.name.identifier)
              captured_local(scope, local.name.identifier, inferred_type(local))
            else
              local(containing_scope(local), local.name.identifier, inferred_type(local))
            end
          end
        end

        def local(scope, name, type)
          type.load(@method, @method.local(scoped_local_name(name, scope), type))
        end

        def captured_local(scope, name, type)
          captured_local_declare(scope, name, type)
          binding_reference
          @method.getfield(scope.binding_type, name, type)
        end

        def visitLocalAssignment(local, expression)
          scope = get_scope(local)
          if scope.has_binding? && scope.captured?(local.name.identifier)
            captured_local_assign(local, expression)
          else
            local_assign(local, expression)
          end
        end

        def local_assign(local, expression)
          name = local.name.identifier
          type = inferred_type(local)
          scope = containing_scope(local)
          declare_local(scope, name, type)

          visit(local.value, true)

          # if expression, dup the value we're assigning
          @method.dup if expression
          set_position(local.position)
          type.store(@method, @method.local(scoped_local_name(name, scope), type))
        end

        def captured_local_assign(node, expression)
          scope, name, type = containing_scope(node), node.name.identifier, inferred_type(node)
          captured_local_declare(scope, name, type)
          binding_reference
          visit(node.value, true)
          @method.dup_x2 if expression
          set_position(node.position)
          @method.putfield(scope.binding_type, name, type)
        end

        def visitFieldAccess(field, expression)
          return nil unless expression
          name = field.name.identifier

          real_type = declared_fields[name] || inferred_type(field)
          declare_field(name, real_type, [], field.isStatic)

          set_position(field.position)
          # load self object unless static
          method.aload 0 unless static || field.isStatic

          if static || field.isStatic
            @method.getstatic(@class, name, inferred_type(field))
          else
            @method.getfield(@class, name, inferred_type(field))
          end
        end

        def declared_fields
          @declared_fields ||= {}
          @declared_fields[@class] ||= {}
        end

        def declare_field(name, type, annotations, static_field)
          # TODO confirm types are compatible
          unless declared_fields[name]
            declared_fields[name] = type
            field = if static || static_field
              @class.private_static_field name, type
            else
              @class.private_field name, type
            end
            annotate(field, annotations)
          end
        end

        def visitFieldDeclaration(decl, expression)
          declare_field(decl.name.identifier, inferred_type(decl), decl.annotations, decl.isStatic)
        end

        def visitFieldAssign(field, expression)
          name = field.name.identifier

          real_type = declared_fields[name] || inferred_type(field)

          declare_field(name, real_type, field.annotations, field.isStatic)

          method.aload 0 unless static || field.isStatic
          visit(field.value, true)
          if expression
            instruction = 'dup'
            instruction << '2' if real_type.wide?
            instruction << '_x1' unless static || field.isStatic
            method.send instruction
          end
          set_position(field.position)
          if static || field.isStatic
            @method.putstatic(@class, name, real_type)
          else
            @method.putfield(@class, name, real_type)
          end
        end

        def visitSimpleString(string, expression)
          set_position(string.position)
          @method.ldc(string.value) if expression
        end

        def visitStringConcat(strcat, expression)
          set_position(strcat.position)
          if expression
            # could probably be more efficient with non-default constructor
            builder_class = @typer.type_system.type(nil, 'java.lang.StringBuilder')
            @method.new builder_class
            @method.dup
            @method.invokespecial builder_class, "<init>", [@method.void]

            strcat.strings.each do |node|
              visit(node, true)
              method = find_method(builder_class, "append", [inferred_type(node)], nil, false)
              if method
                @method.invokevirtual builder_class, "append", [method.return_type, *method.argument_types]
              else
                log "Could not find a match for #{java::lang::StringBuilder}.append(#{inferred_type(node)})"
                fail "Could not compile"
              end
            end

            # convert to string
            set_position(strcat.position)
            @method.invokevirtual java::lang::StringBuilder.java_class, "toString", [@method.string]
          else
            strcat.strings.each do |node|
              visit(node, false)
            end
          end
        end

        def visitStringEval(node, expression)
          if expression
            visit(node.value, true)
            set_position(node.position)
            inferred_type(node.value).box(@method) if inferred_type(node.value).primitive?
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
            visit(node.value, false)
          end
        end

        def visitBoolean(node, expression)
          if expression
            set_position(node.position)
            node.value ? @method.iconst_1 : @method.iconst_0
          end
        end

        def visitRegex(node, expression)
          # TODO: translate flags to Java-appropriate values
          if node.strings_size == 1
            visit(node.strings(0), expression)
          else
            visitStringConcat(node, expression)
          end
          if expression
            set_position(node.position)
            @method.invokestatic java::util::regex::Pattern, "compile", [java::util::regex::Pattern, @method.string]
          end
        end

        def visitArray(node, expression)
          set_position(node.position)
          if expression
            # create basic arraylist
            @method.new java::util::ArrayList
            @method.dup
            @method.ldc_int node.values_size
            @method.invokespecial java::util::ArrayList, "<init>", [@method.void, @method.int]

            # elements, as expressions
            # TODO: ensure they're all reference types!
            node.values.each do |n|
              @method.dup
              visit(n, true)
              # TODO this feels like it should be in the node.compile itself
              if inferred_type(n).primitive?
                inferred_type(n).box(@method)
              end
              @method.invokeinterface java::util::List, "add", [@method.boolean, @method.object]
              @method.pop
            end

            # make it unmodifiable
            @method.invokestatic java::util::Collections, "unmodifiableList", [java::util::List, java::util::List]
          else
            # elements, as non-expressions
            # TODO: ensure they're all reference types!
            node.values.each do |n|
              visit(n, true)
              # TODO this feels like it should be in the node.compile itself
              if inferred_type(n).primitive?
                inferred_type(n).box(@method)
              end
            end
          end
        end

        def visitHash(node, expression)
          set_position(node.position)
          if expression
            # create basic arraylist
            @method.new java::util::HashMap
            @method.dup
            @method.ldc_int [node.size / 0.75, 16].max.to_i
            @method.invokespecial java::util::HashMap, "<init>", [@method.void, @method.int]

            node.each do |e|
              @method.dup
              [e.key, e.value].each do |n|
                visit(n, true)
                # TODO this feels like it should be in the node.compile itself
                if inferred_type(n).primitive?
                  inferred_type(n).box(@method)
                end
              end
              @method.invokeinterface java::util::Map, "put", [@method.object, @method.object, @method.object]
              @method.pop
            end
          else
            # elements, as non-expressions
            node.each do |n|
              visit(n.key, false)
              visit(n.value, false)
            end
          end
        end

        def visitNot(node, expression)
          visit(node.value, expression)
          if expression
            set_position(node.position)
            type = inferred_type(node.value)
            done = @method.label
            else_label = @method.label
            if type.primitive?
              @method.ifeq else_label
            else
              @method.ifnull else_label
            end
            @method.iconst_0
            @method.goto done
            else_label.set!
            @method.iconst_1
            done.set!
          end
        end

        def visitNull(node, expression)
          if expression
            set_position(node.position)
            @method.aconst_null
          end
        end

        def visitImplicitNil(node, expression)
          visitNull(node, expression)
        end

        def visitBindingReference(node, expression)
          binding_reference
        end

        def binding_reference
          @method.aload(@method.local('$binding'))
        end

        def real_self
          method.aload(0)
        end

        def set_position(position)
          # TODO support positions from multiple files
          @method.line(position.start_line - 1) if @method && position
        end

        def print(print_node)
          @method.getstatic System, "out", PrintStream
          print_node.parameters.each {|param| visit(param, true)}
          params = print_node.parameters.map {|param| inferred_type(param).jvm_type}
          method_name = print_node.println ? "println" : "print"
          method = find_method(PrintStream.java_class, method_name, params, nil, false)
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

        def visitReturn(return_node, expression)
          visit(return_node.value, true) if return_node.value
          handle_ensures(find_ensures(MethodDefinition))
          set_position return_node.position
          inferred_type(return_node).return(@method)
        end

        def visitRaise(node, expression)
          visit(node.args(0), true)
          set_position(node.position)
          @method.athrow
        end

        def visitRescue(rescue_node, expression)
          start = @method.label.set!
          body_end = @method.label
          done = @method.label
          visit(rescue_node.body, expression && rescue_node.else_clause.size == 0)
          body_end.set!
          visit(rescue_node.else_clause, expression) if rescue_node.else_clause.size > 0
          return if start.label.offset == body_end.label.offset
          @method.goto(done)
          rescue_node.clauses.each do |clause|
            target = @method.label.set!
            if clause.name
              types = clause.types.map {|t| inferred_type(t)}
              widened_type = types.inject {|a, b| a.widen(b)}
              @method.astore(declare_local(introduced_scope(clause), clause.name.identifier, widened_type))
            else
              @method.pop
            end
            declare_locals(introduced_scope(clause))
            visit(clause.body, expression)
            @method.goto(done)
            clause.types.each do |type|
              type = inferred_type(type)
              @method.trycatch(start, body_end, target, type)
            end
          end
          done.set!
        end

        def handle_ensures(nodes)
          nodes.each do |ensure_node|
            visit(ensure_node.ensureClause, false)
          end
        end

        def visitEnsure(node, expression)
          # TODO this doesn't appear to be used
          #node.state = @method.label  # Save the ensure target for JumpNodes
          start = @method.label.set!
          body_end = @method.label
          done = @method.label
          push_jump_scope(node) do
            visit(node.body, expression)  # First compile the body
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

        def visitEmptyArray(node, expression)
          if expression
            visit(node.size, true)
            type = @typer.type_system.get(@scoper.getScope(node), node.type).resolve
            type.newarray(@method)
          end
        end

        class ClosureCompiler < JVMBytecode
          def initialize(file, type, parent, scoper, typer)
            super(scoper, typer)
            @file = file
            @type = type
            @jump_scope = []
            @parent = parent
          end

          def prepare_binding(node)
            scope = introduced_scope(node)
            if scope.has_binding?
              type = scope.binding_type
              @binding = @parent.get_binding(type)
              @method.aload 0
              @method.getfield(@class, 'binding', @binding)
              type.store(@method, @method.local('$binding', type))
            else
              log "No binding for #{node} (#{scope.has_binding?} #{scope.parent} #{scope.parent && scope.parent.has_binding?})"
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
end
