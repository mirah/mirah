module Duby::AST
  class Import < Node
    attr_accessor :short
    attr_accessor :long
    def initialize(parent, line_number, short, long)
      @short = short
      @long = long
      super(parent, line_number, [])
      Duby::AST.type_factory.alias(short, long) if Duby::AST.type_factory
    end

    def to_s
      "Import(#{short} = #{long})"
    end

    def infer(typer)
      # add both the meta and non-meta imports
      typer.alias_types(short, long)
      typer.no_type
    end
  end

  class EmptyArray < Node
    attr_accessor :size
    attr_accessor :component_type
    def initialize(parent, line_number, type)
      super(parent, line_number, [])
      @component_type = type
      @size = size
      @inferred_type = Duby::AST::type(type.name, true)

      @size = yield(self)
    end

    def infer(typer)
      size.infer(typer)
      resolved!
      return @inferred_type
    end
  end
end