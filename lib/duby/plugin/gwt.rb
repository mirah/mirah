module Duby::AST
  # From class MethodDefinition
  class JsniMethodDefinition < Node
    include Annotated
    include Named
    include Scope
    include Binding

    child :signature
    child :arguments
    child :body

    attr_accessor :defining_class

    def initialize(parent, line_number, name, annotations=[], &block)
      @annotations = annotations
      super(parent, line_number, &block)
      @name = name
    end

    def compile(compiler, expression)
      compiler.define_jsni_method(self)
    end

    def name
      super
    end

    def infer(typer)
      @defining_class ||= typer.self_type
      resolve_if(typer) do
        argument_types = arguments.map { |arg| typer.infer(arg) }
        if argument_types.all?
          typer.learn_method_type(defining_class, name, argument_types,
            signature[:return], signature[:throws])
        end
      end
    end

    # TODO: JSNI can be static.
    def static?
      false
    end
  end

  defmacro 'def_jsni' do | transformer, fcall, parent |
    # Must be FCallNode with 3 args.
    # undefined method `args_node' for VCallNode
    args_node = fcall.args_node

    unless fcall.class == JRubyAst::FCallNode &&
        args_node.size == 3
      raise "def_jsni must have 3 arguments."
    end
 
    # From transform.rb
    JsniMethodDefinition.new(parent,
      fcall.position,
      fcall.name,
      transformer.annotations) do |defn|
      signature = {:return => args_node.first.type_reference(defn)}

      method = fcall.args_node[1][0]
      hash_node = method[0][0]

      args = Arguments.new(defn, defn.position) do |args_new|
        arg_list = hash_node.child_nodes.each_slice(2) do |name, type|
          # p 'name', name, 'type', type
          position = Java::OrgJrubyparser::SourcePosition.
            combinePosition(name.position, type.position)
          name = name.name
          type = type.type_reference(args_node)
          signature[name.intern] = type
          # defn is a Duby::AST::Node
          RequiredArgument.new(args_new, position, name)          
        end
        # `compile_ast': undefined method `position' for nil:NilClass (NoMethodError)
        [arg_list, nil, nil, nil]
      end

      body_node = transformer.transform(args_node.last, defn)

      [
        signature,
        args,
        body_node
      ]
    end
  end
end