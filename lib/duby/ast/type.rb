module Duby::AST
  class Import < Node
    attr_accessor :short
    attr_accessor :long
    def initialize(parent, short, long)
      @short = short
      @long = long
      super(parent, [])
    end

    def to_s
      "Import(#{short} = #{long})"
    end

    def infer(typer)
      # add both the meta and non-meta imports
      typer.known_types[TypeReference.new(short, false, true)] = TypeReference.new(long, false, true)
      typer.known_types[TypeReference.new(short, false, false)] = TypeReference.new(long, false, false)
      TypeReference::NoType
    end
  end

  class EmptyArray < Node
    attr_accessor :size
    attr_accessor :component_type
    def initialize(parent, type, size)
      super(parent, [])

      @size = size
      @component_type = type
      @inferred_type = TypeReference.new(type.name, true)
      resolved!
    end

    def infer(typer)
      return @inferred_type
    end
  end
end