require 'fileutils'

module Duby::AST

  class MacroDefinition < Node
    include Named

    child :arguments
    child :body

    attr_accessor :proxy

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
    end

    def infer(typer)
      resolve_if(typer) do
        self_type = typer.self_type
        extension_name = "%s$%s" % [self_type.name,
                                    typer.transformer.tmp("Extension%s")]
        klass = build_and_load_extension(self_type,
                                         extension_name,
                                         typer.transformer.state)

        # restore the self type since we're sharing a type factory
        typer.known_types['self'] = self_type

        arg_types = argument_types
        macro = self_type.add_macro(name, *arg_types) do |duby, call|
          expander = klass.constructors[0].newInstance(duby, call)
          expander.expand
        end
        if arguments[-1].kind_of?(BlockArgument) && arguments[-1].optional?
          arg_types.pop
          typer.self_type.add_method(name, arg_types, macro)
        end
        proxy.__inline__(Noop.new(parent, position))
        proxy.infer(typer)
      end
    end

    def argument_types
      arguments.map do |arg|
        if arg.kind_of?(BlockArgument)
          TypeReference::BlockType
        else
          # TODO support typed args. Also there should be a way
          # to accept any AST node.
          Duby::JVM::Types::Object
        end
      end
    end

    def signature
      args = argument_types
      if args.size > 0 && args[-1].block?
        args[-1] = BiteScript::ASM::Type.getObjectType('duby.lang.compiler.Block')
      end
      [nil] + args
    end

    def build_and_load_extension(parent, name, state)
      transformer = Duby::Transform::Transformer.new(state)
      ast = build_ast(name, parent, transformer)
      puts ast.inspect if state.verbose
      classes = compile_ast(name, ast, transformer)
      loader = DubyClassLoader.new(
          JRuby.runtime.jruby_class_loader, classes)
      klass = loader.loadClass(name, true)
      annotate(parent, name)
      klass
    end

    def annotate(type, name)
      node = type.unmeta.node
      if node
        extension = node.annotation('duby.anno.Extensions')
        extension ||= begin
          node.annotations << Annotation.new(
              nil, nil, BiteScript::ASM::Type.getObjectType('duby/anno/Extensions'))
          node.annotations[-1].runtime = false
          node.annotations[-1]
        end
        extension['macros'] ||= []
        macro = Annotation.new(nil, nil,
                               BiteScript::ASM::Type.getObjectType('duby/anno/Macro'))
        macro['name'] = name
        macro['signature'] = BiteScript::Signature.signature(*signature)
        extension['macros'] << macro
      else
        puts "Warning: No ClassDefinition for #{type.name}. Macros can't be loaded from disk."
      end
    end

    def compile_ast(name, ast, transformer)
      filename = name.gsub(".", "/")
      typer = Duby::Typer::JVM.new(filename, transformer)
      typer.infer(ast)
      typer.resolve(true)
      compiler = Duby::Compiler::JVM.new(filename)
      ast.compile(compiler, false)
      class_map = {}
      compiler.generate do |outfile, builder|
        outfile = "#{transformer.destination}#{outfile}"
        FileUtils.mkdir_p(File.dirname(outfile))
        File.open(outfile, 'w') do |f|
          bytes = builder.generate
          name = builder.class_name.gsub(/\//, '.')
          class_map[name] = bytes
          f.write(bytes)
        end
      end
      class_map
    end

    def build_ast(name, parent, transformer)
      # TODO should use a new type factory too.
      ast = Duby::AST.parse_ruby("import duby.lang.compiler.Node")
      ast = transformer.transform(ast, nil)

      # Start building the extension class
      extension = transformer.define_class(position, name)
      #extension.superclass = Duby::AST.type('duby.lang.compiler.Macro')
      extension.interfaces = [Duby::AST.type('duby.lang.compiler.Macro')]

      # The constructor just saves the state
      extension.define_constructor(
          position,
          ['duby', Duby::AST.type('duby.lang.compiler.Compiler')],
          ['call', Duby::AST.type('duby.lang.compiler.Call')]) do |c|
        transformer.eval("@duby = duby;@call = call", '-', c, 'duby', 'call')
      end

      node_type = Duby::AST.type('duby.lang.compiler.Node')

      # expand() parses the arguments out of call and then passes them off to
      # _expand
      expand = extension.define_method(
          position, 'expand', node_type)
      args = []
      arguments.each_with_index do |arg, i|
        # TODO optional args
        args << if arg.kind_of?(BlockArgument)
          "@call.block"
        else
          "Node(args.get(#{i}))"
        end
      end
      expand.body = transformer.eval(<<-end)
        args = @call.arguments
        _expand(#{args.join(', ')})
      end
      actual_args = arguments.map do |arg|
        [arg.name, node_type, arg.position]
      end
      m = extension.define_method(position, '_expand', node_type, *actual_args)
      m.body = self.body
      ast
    end
  end

  defmacro('defmacro') do |duby, fcall, parent|
    macro = fcall.args_node[0]
    block_arg = nil
    args_node = macro.args_node
    body = macro.iter_node || fcall.iter_node
    if args_node.respond_to? :getBodyNode
      block_arg = args_node.body_node
      args_node = args_node.args_node
      body = fcall.iter_node
    end
    MacroDefinition.new(parent, fcall.position, macro.name) do |mdef|
      # TODO optional args?
      args = if args_node
        args_node.map do |arg|
          case arg
          when JRubyAst::LocalAsgnNode
            OptionalArgument.new(mdef, arg.position, arg.name) do |optarg|
              # TODO check that they actually passed nil as the value
              Null.new(parent, arg.value_node.position)
            end
          when JRubyAst::VCallNode, JRubyAst::LocalVarNode
            RequiredArgument.new(mdef, arg.position, arg.name)
          end
        end
      else
        []
      end
      if block_arg
        args << BlockArgument.new(mdef, block_arg.position, block_arg.name)
        args[-1].optional = block_arg.kind_of?(JRubyAst::LocalAsgnNode)
      end
      body_node = duby.transform(body.body_node, mdef) if body.body_node
      [args,  body_node]
    end
  end

  defmacro('puts') do |transformer, fcall, parent|
    Call.new(parent, fcall.position, "println") do |x|
      args = if fcall.respond_to?(:args_node) && fcall.args_node
        fcall.args_node.child_nodes.map do |arg|
          transformer.transform(arg, x)
        end
      else
        []
      end
      [
        Call.new(x, fcall.position, "out") do |y|
          [
            Constant.new(y, fcall.position, "System"),
            []
          ]
        end,
        args,
        nil
      ]
    end
  end

  defmacro('print') do |transformer, fcall, parent|
    Call.new(parent, fcall.position, "print") do |x|
      args = if fcall.respond_to?(:args_node) && fcall.args_node
        fcall.args_node.child_nodes.map do |arg|
          transformer.transform(arg, x)
        end
      else
        []
      end
      [
        Call.new(x, fcall.position, "out") do |y|
          [
            Constant.new(y, fcall.position, "System"),
            []
          ]
        end,
        args,
        nil
      ]
    end
  end

  class InlineCode
    def initialize(&block)
      @block = block
    end

    def inline(transformer, call)
      @block.call(transformer, call)
    end
  end
end