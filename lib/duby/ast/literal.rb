module Duby::AST
  class Array < Node
    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer)
      @inferred_type = typer.array_type
    end
  end

  class Fixnum < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type = typer.fixnum_type
    end

    def ==(other)
      @literal == other.literal
    end

    def eql?(other)
      self.class == other.class && @literal.eql?(other.literal)
    end
  end

  class Float < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type = typer.float_type
    end
  end

  class Hash < Node; end

  class String < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.string_type
    end
  end

  class Symbol < Node; end

  class Boolean < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.boolean_type
    end
  end

  class Null < Node
    include Literal

    def initialize(parent, line_number)
      super(parent, line_number)
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.null_type
    end
  end
end