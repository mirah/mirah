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
  module JVM
    module Compiler
      java_import 'mirah.lang.ast.ClassDefinition'
      java_import 'mirah.lang.ast.StaticMethodDefinition'
      java_import 'mirah.lang.ast.SimpleNodeVisitor'
      java_import 'mirah.lang.ast.NodeScanner'

      class Base < SimpleNodeVisitor
        attr_accessor :filename, :method, :static, :class
        include Mirah::Logging::Logged

        class CompilationError < Mirah::NodeError
        end

        def logger_name
          "org.mirah.ruby.JVM.Compiler.Base"
        end

        def initialize(scoper, typer)
          super()
          @jump_scope = []
          @bindings = Hash.new {|h, type| h[type] = type.define(@file)}
          @captured_locals = Hash.new {|h, binding| h[binding] = {}}
          @self_scope = nil
          @scoper = scoper
          @typer = typer
        end

        def defaultNode(node, expression)
          raise ArgumentError, "Can't compile node #{node}"
        end

        def visit(node, expression)
          begin
            node.accept(self, expression)
          rescue Exception => ex
            raise Mirah::InternalCompilerError.wrap(ex, node)
          end
        end

        def get_scope(node)
          @scoper.get_scope(node)
        end

        def introduced_scope(node)
          @scoper.get_introduced_scope(node)
        end

        def containing_scope(node)
          scope = get_scope(node)
          name = node.name.identifier
          while (!scope.shadowed?(name) && scope.parent && scope.parent.include?(name))
            scope = scope.parent
          end
          scope
        end

        def inferred_type(node)
          begin
            @typer.get_inferred_type(node).resolve
          rescue Exception => ex
            raise Mirah::InternalCompilerError.wrap(ex, node)
          end
        end

        def error(message, node)
          raise CompilationError.new(message, node)
        end

        def toplevel_class
          @class = @type.define(@file)
        end

        def generate
          log "Generating #{output_type}..."
          @file.generate do |filename, builder|
            log "  #{builder.class_name}"
            if block_given?
              yield filename, builder
            else
              File.open(filename, 'wb') {|f| f.write(builder.generate)}
            end
          end
          log "...done!"
        end

        # Scans the top level of a file to see if it contains anything outside of a ClassDefinition.
        class ScriptScanner < NodeScanner
          attr_reader :found_other, :found_method
          def enterDefault(node, arg)
            @found_other = true
            false
          end
          def enterMethodDefinition(node, arg)
            @found_method = true
            false
          end
          def enterStaticMethodDefinition(node, arg)
            @found_method = true
            false
          end
          def enterConstructorDefinition(node, arg)
            @found_method = true
            false
          end
          def enterPackage(node, arg)
            # ignore
            false
          end
          def enterClassDefinition(node, arg)
            # ignore
            false
          end
          def enterInterfaceDeclaration(node, arg)
            # ignore
            false
          end
          def enterImport(node, arg)
            # ignore
            false
          end
          def enterNodeList(node, arg)
            # Scan the children
            true
          end
        end

        def visitMacroDefinition(node, expression)
          # ignore. It was already compiled
        end

        def visitScript(script, expression)
          @static = true
          @filename = File.basename(script.position.source.name)
          classname = Mirah::JVM::Compiler::JVMBytecode.classname_from_filename(@filename)
          @type = @typer.type_system.type(get_scope(script), classname)
          @file = file_builder(@filename)
          body = script.body
          scanner = ScriptScanner.new
          scanner.scan(body, expression)
          need_class = scanner.found_method || scanner.found_other
          if need_class
            @class = @type.define(@file)
            if scanner.found_other
              # Generate the main method
              with :method => @class.main do
                log "Starting main method"

                @method.start
                @current_scope = get_scope(script)
                declare_locals(@current_scope)
                begin_main

                prepare_binding(script) do
                  visit(body, false)
                end

                finish_main
                @method.stop
              end
              log "Main method complete!"
            else
              visit(body, false)
            end
            @class.stop
          else
            visit(body, false)
          end
        end

        def visitNoop(node, expression)
        end

        def begin_main; end
        def finish_main; end

        # arg_types must be an Array
        def create_method_builder(name, node, static, exceptions, return_type, arg_types)
          visibility = :public  # TODO
          @class.build_method(name.to_s, visibility, static,
          exceptions, return_type, *arg_types)
        end

        def base_define_method(node)
          name = node.name.identifier.sub(/=$/, '_set')
          args = visit(node.arguments, true)
          is_static = self.static || node.kind_of?(StaticMethodDefinition)
          if name == "initialize" && is_static
            name = "<clinit>"
          end
          arg_types = args.map { |arg| inferred_type(arg) }
          return_type = inferred_type(node).return_type
          exceptions = []  # TODO

          with :static => is_static, :current_scope => introduced_scope(node) do
            method = create_method_builder(name, node, @static, exceptions,
                                           return_type, arg_types)
            annotate(method, node.annotations)
            yield method, arg_types
          end

          arg_types_for_opt = []
          args_for_opt = []
          if args
            args.each do |arg|
              if AST::OptionalArgument === arg
                new_args = arg_types_for_opt
                method = create_method_builder(name, node, @static, exceptions,
                return_type, new_args)
                with :method => method do
                  log "Starting new method #{name}(#{arg_types_for_opt})"

                  annotate(method, node.annotations)
                  @method.start

                  define_optarg_chain(name, arg,
                  return_type,
                  args_for_opt,
                  arg_types_for_opt)

                  @method.stop
                end
              end
              arg_types_for_opt << inferred_type(arg)
              args_for_opt << arg
            end
          end
        end

        def visitConstructorDefinition(node, expression)
          args = visit(node.arguments, true)
          arg_types = args.map { |arg| inferred_type(arg) }
          exceptions = []  # node.signature[:throws]
          visibility = :public  # node.visibility
          method = @class.build_constructor(visibility, exceptions, *arg_types)
          annotate(method, node.annotations)
          with :current_scope => introduced_scope(node) do
            yield(method, args)
          end
        end

        def visitClassDefinition(class_def, expression)
          log "Compiling class #{class_def.name.identifier}"
          with(:type => inferred_type(class_def),
               :class => inferred_type(class_def).define(@file),
               :static => false) do
            annotate(@class, class_def.annotations)
            visit(class_def.body, false) if class_def.body
            @class.stop
          end
        end

        def visitArguments(args, expression)
          result = []
          args.required.each {|arg| result << arg}
          args.optional.each {|arg| result << arg}
          result << args.rest if args.rest
          args.required2.each {|arg| result << arg}
          result << args.block if args.block
          result
        end

        def visitStaticMethodDefinition(mdef, expression)
          visitMethodDefinition(mdef, expression)
        end

        def visitNodeList(body, expression)
          saved_self = @self_scope
          new_scope = introduced_scope(body)
          if new_scope
            declare_locals(new_scope)
            if new_scope != @self_scope
              if new_scope.self_node && new_scope.self_node != :self
                # FIXME This is a horrible hack!
                # Instead we should eliminate unused self's.
                unless new_scope.self_type.name == 'mirah.impl.Builtin'
                  local_assign(
                  new_scope, 'self', new_scope.self_type, false, new_scope.self_node)
                end
              end
              @self_scope = new_scope
            end
          end
          # all except the last element in a body of code is treated as a statement
          i, last = 0, body.size - 1
          while i < last
            visit(body.get(i), false)
            i += 1
          end
          if last >= 0
            yield body.get(last)
          else
            yield nil
          end
          @self_scope = saved_self
        end

        def visitClassAppendSelf(node, expression)
          with :static => true, :current_scope => introduced_scope(node) do
            visit(node.body, expression)
          end
        end

        def visitPackage(node, expression)
          visit(node.body, expression) if node.body
        end

        def scoped_body(scope, expression)
          body(scope, expression)
        end

        def scoped_local_name(name, scope=nil)
          if scope.nil? || scope == @current_scope
            name
          else
            "#{name}$#{scope.object_id}"
          end
        end

        def visitImport(node, expression)
        end

        def visitFixnum(node, expression)
          if expression
            inferred_type(node).literal(method, node.value)
          end
        end
        alias visitFloat visitFixnum

        def visitSelf(node, expression)
          if expression
            set_position(node.position)
            scope = get_scope(node)
            if scope.self_node && scope.self_node != :self
              local(scope, 'self', scope.self_type)
            else
              real_self
            end
          end
        end

        def visitImplicitSelf(node, expression)
          visitSelf(node, expression)
        end

        def visitUnquote(node, expression)
          body = node.nodes
          i, last = 0, body.size - 1
          while i < last
            visit(body.get(i), false)
            i += 1
          end
          if last >= 0
            visit(body.get(last), expression)
          else
            visitImplicitNil(node, expression)
          end
        end

        def get_binding(type)
          @bindings[type]
        end

        def declared_captures(binding=nil)
          @captured_locals[binding || @binding]
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
end
