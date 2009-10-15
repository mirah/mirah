module Duby::AST
  class ClassDefinition < Node
    include Named
    include Scope
    attr_accessor :superclass, :body, :interfaces
        
    def initialize(parent, line_number, name, &block)
      @interfaces = []
      @name = name
      super(parent, line_number, &block)
      if Duby::AST.type_factory.respond_to? :declare_type
        Duby::AST.type_factory.declare_type(self)
      end
      @superclass, @body = children
    end
    
    def infer(typer)
      unless resolved?
        superclass = Duby::AST::type(@superclass.name) if @superclass
        @inferred_type ||= typer.define_type(name, superclass, @interfaces) do
          if body
            typer.infer(body)
          else
            typer.no_type
          end
        end
        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
    
    def implements(*types)
      raise ArgumentError if types.any? {|x| x.nil?}
      @interfaces.concat types
    end
  end
  
  defmacro('implements') do |transformer, fcall, parent|
    interfaces = fcall.args_node.child_nodes.map do |interface|
      interface.type_reference(parent)
    end
    parent.parent.implements(*interfaces)
    Noop.new(parent, fcall.position)
  end

  class InterfaceDeclaration < ClassDefinition
    attr_accessor :superclass, :body, :interfaces
        
    def initialize(parent, line_number, name)
      super(parent, line_number, name) {|p| }
      @interfaces = []
      @name = name
      @children = yield(self)
      @interfaces, @body = children
    end
  end

  defmacro('interface') do |transformer, fcall, parent|
    raise "Interface name required" unless fcall.args_node
    interfaces = fcall.args_node.child_nodes.to_a
    interface_name = interfaces.shift
    if (JRubyAst::CallNode === interface_name &&
        interface_name.args_node.size == 1)
      interfaces.unshift(interface_name.args_node.get(0))
      interface_name = interface_name.receiver_node
    end
    raise 'Interface body required' unless fcall.iter_node
    InterfaceDeclaration.new(parent, fcall.position,
                             interface_name.name) do |interface|
      [interfaces.map {|p| p.type_reference(interface)},
       if fcall.iter_node.body_node
         transformer.transform(fcall.iter_node.body_node, interface)
       end
      ]
    end
  end

  class FieldDeclaration < Node
    include Named
    include ClassScoped
    include Typed

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
      @type = children[0]
    end

    def infer(typer)
      unless resolved?
        resolved!
        @inferred_type = typer.known_types[type]
        if @inferred_type
          resolved!
          typer.learn_field_type(scope, name, @inferred_type)
        else
          typer.defer(self)
        end
      end
      @inferred_type
    end
  end
      
  class FieldAssignment < Node
    include Named
    include Valued
    include ClassScoped
        
    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @value = children[0]
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.learn_field_type(scope, name, typer.infer(value))

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
      
  class Field < Node
    include Named
    include ClassScoped
    
    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.field_type(scope, name)

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
end