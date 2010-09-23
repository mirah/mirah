module Duby::AST
  class Import < Node
    include Scoped
    attr_accessor :short
    attr_accessor :long
    def initialize(parent, line_number, short, long)
      @short = short
      @long = long
      super(parent, line_number, [])
      scope.static_scope.import(long, short)
    end

    def to_s
      "Import(#{short} = #{long})"
    end

    def infer(typer)
      typer.no_type
    end
  end

  defmacro('import') do |transformer, fcall, parent|
    case fcall.parameters.size
    when 1
      node = fcall.parameters[0]
      case node
      when String
        long = node.literal
        short = long[(long.rindex('.') + 1)..-1]
      when Call
        case node.parameters.size
        when 0
          pieces = [node.name]
          while Call === node
            node = node.target
            pieces << node.name
          end
          long = pieces.reverse.join '.'
          short = pieces[0]
        when 1
          arg = node.parameters[0]
          unless (FunctionalCall === arg &&
                  arg.name == 'as' && arg.parameters.size == 1)
            raise Duby::TransformError.new("unknown import syntax", fcall)
          end
          short = arg.parameters[0].name
          pieces = [node.name]
          while Call === node
            node = node.target
            pieces << node.name
          end
          long = pieces.reverse.join '.'
        else
          raise Duby::TransformError.new("unknown import syntax", args_node)
        end
      else
        raise Duby::TransformError.new("unknown import syntax", args_node)
      end
    when 2
      short = fcall.parameters[0].literal
      long = fcall.parameters[1].literal
    else
      raise Duby::TransformError.new("unknown import syntax", args_node)
    end
    Import.new(parent, fcall.position, short, long)
  end

  class EmptyArray < Node
    attr_accessor :size
    attr_accessor :component_type
    child :type_node
    child :size

    def initialize(*args)
      super(*args)
    end

    def infer(typer)
      resolve_if(typer) do
        @component_type = type_node.type_reference(typer)
        typer.infer(size)
        typer.type_reference(nil, @component_type, true)
      end
    end
  end

  class Builtin < Node
    def infer(typer)
      resolve_if(typer) {Duby::AST.type(nil, 'mirah.impl.Builtin')}
    end
  end
end