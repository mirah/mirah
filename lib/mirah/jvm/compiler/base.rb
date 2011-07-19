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
      class Base
        attr_accessor :filename, :method, :static, :class

        class CompilationError < Mirah::NodeError
        end

        def initialize
          @jump_scope = []
          @bindings = Hash.new {|h, type| h[type] = type.define(@file)}
          @captured_locals = Hash.new {|h, binding| h[binding] = {}}
          @self_scope = nil
        end

        def error(message, node)
          raise CompilationError.new(message, node)
        end

        def compile(ast, expression = false)
          begin
            ast.compile(self, expression)
          rescue => ex
            raise Mirah::InternalCompilerError.wrap(ex, ast)
          end
          log "Compilation successful!"
        end

        def log(message); Mirah::JVM::Compiler::JVMBytecode.log(message); end

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

        def define_main(script)
          @static = true
          @filename = File.basename(script.filename)
          classname = Mirah::JVM::Compiler::JVMBytecode.classname_from_filename(@filename)
          @type = AST.type(script, classname)
          @file = file_builder(@filename)

          # Define a main method unless all of the script's children are 'top level'
          # nodes (e.g. Import, ClassDefinition, InterfaceDeclaration).
          unless script.body.children.all? { |c| c.top_level? }
            @class = @type.define(@file)
            with :method => @class.main do
              log "Starting main method"

              @method.start
              @current_scope = script.static_scope
              declare_locals(@current_scope)
              begin_main

              prepare_binding(script) do
                script.body.compile(self, false)
              end

              finish_main
              @method.stop
            end
            @class.stop

            log "Main method complete!"
          else
            script.body.compile(self, false)
          end
        end

        def begin_main; end
        def finish_main; end

        # arg_types must be an Array
        def create_method_builder(name, node, static, exceptions, return_type, arg_types)
          @class.build_method(name.to_s, node.visibility, static,
          exceptions, return_type, *arg_types)
        end

        def base_define_method(node, args_are_types)
          name, signature, args = node.name, node.signature, node.arguments.args
          if name == "initialize" && node.static?
            name = "<clinit>"
          end
          if args_are_types
            arg_types = args.map { |arg| arg.inferred_type } if args
          else
            arg_types = args
          end
          arg_types ||= []
          return_type = signature[:return]
          exceptions = signature[:throws]

          with :static => @static || node.static?, :current_scope => node.static_scope do
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
                new_args = if args_are_types
                  arg_types_for_opt
                else
                  args_for_opt
                end
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
              arg_types_for_opt << arg.inferred_type
              args_for_opt << arg
            end
          end
        end

        def constructor(node, args_are_types)
          args = node.arguments.args || []
          arg_types = if args_are_types
            args.map { |arg| arg.inferred_type }
          else
            args
          end
          exceptions = node.signature[:throws]
          method = @class.build_constructor(node.visibility, exceptions, *arg_types)
          annotate(method, node.annotations)
          with :current_scope => node.static_scope do
            yield(method, args)
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

        def body(body, expression)
          saved_self = @self_scope
          if body.kind_of?(Mirah::AST::ScopedBody)
            scope = body.static_scope
            declare_locals(scope)
            if scope != @self_scope
              if scope.self_node && scope.self_node != :self
                # FIXME This is a horrible hack!
                # Instead we should eliminate unused self's.
                unless scope.self_type.name == 'mirah.impl.Builtin'
                  local_assign(
                  scope, 'self', scope.self_type, false, scope.self_node)
                end
              end
              @self_scope = scope
            end
          end
          # all except the last element in a body of code is treated as a statement
          i, last = 0, body.children.size - 1
          while i < last
            body.children[i].compile(self, false)
            i += 1
          end
          yield body.children[last] if last >= 0
          @self_scope = saved_self
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

        def import(short, long)
        end

        def fixnum(type, value)
          type.literal(method, value)
        end
        alias float fixnum

        def compile_self
          if @self_scope && @self_scope.self_node && @self_scope.self_node != :self
            local(@self_scope, 'self', @self_scope.self_type)
          else
            real_self
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