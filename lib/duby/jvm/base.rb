module Duby
  module Compiler
    class JVMCompilerBase
      attr_accessor :filename, :method, :static, :class

      def initialize(filename)
        @filename = File.basename(filename)
        @static = true
        classname = JVM.classname_from_filename(filename)
        @type = AST::type(classname)
        @jump_scope = []
        @bindings = Hash.new {|h, type| h[type] = type.define(@file)}
        @captured_locals = Hash.new {|h, binding| h[binding] = {}}
      end

      def compile(ast, expression = false)
        ast.compile(self, expression)
        log "Compilation successful!"
      end

      def log(message); JVM.log(message); end

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
            File.open(filename, 'w') {|f| f.write(builder.generate)}
          end
        end
        log "...done!"
      end

      def define_main(script)
        body = script.body
        body = body[0] if body.children.size == 1
        if body.class != AST::ClassDefinition
          @class = @type.define(@file)
          with :method => @class.main do
            log "Starting main method"

            @method.start

            begin_main

            prepare_binding(script) do
              body.compile(self, false)
            end

            finish_main
            @method.stop
          end
          @class.stop
        else
          body.compile(self, false)
        end

        log "Main method complete!"
      end

      def begin_main; end
      def finish_main; end

      def define_method(node, args_are_types)
        name, signature, args = node.name, node.signature, node.arguments.args
        if args_are_types
          arg_types = args.map { |arg| arg.inferred_type } if args
        else
          arg_types = args
        end
        arg_types ||= []
        return_type = signature[:return]
        exceptions = signature[:throws]

        with :static => @static || node.static? do
          if @static
            method = @class.public_static_method(name.to_s, exceptions, return_type, *arg_types)
          else
            method = @class.public_method(name.to_s, exceptions, return_type, *arg_types)
          end
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
              if @static
                method = @class.public_static_method(name.to_s, exceptions, return_type, *new_args)
              else
                method = @class.public_method(name.to_s, exceptions, return_type, *new_args)
              end

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
        method = @class.public_constructor(exceptions, *arg_types)
        annotate(method, node.annotations)
        yield(method, args)
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
        # all except the last element in a body of code is treated as a statement
        i, last = 0, body.children.size - 1
        while i < last
          body.children[i].compile(self, false)
          i += 1
        end
        yield body.children[last] if last >= 0
      end

      def import(short, long)
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