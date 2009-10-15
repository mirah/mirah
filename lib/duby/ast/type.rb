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

  defmacro('import') do |transformer, fcall, parent|
    args_node = fcall.args_node
    case args_node
    when JRubyAst::ArrayNode
      case args_node.size
      when 1
        node = args_node.get(0)
        case node
        when JRubyAst::StrNode
          long = node.value
          short = long[(long.rindex('.') + 1)..-1]
        when JRubyAst::CallNode
          case node.args_node.size
          when 0
            pieces = [node.name]
            while node.kind_of? JRubyAst::CallNode
              node = node.receiver_node
              pieces << node.name
            end
            long = pieces.reverse.join '.'
            short = pieces[0]
          when 1
            arg = node.args_node.get(0)
            unless (JRubyAst::FCallNode === arg &&
                    arg.name == 'as' && arg.args_node.size == 1)
              raise Duby::TransformError.new("unknown import syntax", args_node)
            end
            short = arg.args_node.get(0).name
            pieces = [node.name]
            while node.kind_of? JRubyAst::CallNode
              node = node.receiver_node
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
        short = args_node.child_nodes[0].value
        long = args_node.child_nodes[1].value
      else
        raise Duby::TransformError.new("unknown import syntax", args_node)
      end
    else
      raise Duby::TransformError.new("unknown import syntax", args_node)
    end
    Import.new(parent, fcall.position, short, long)
  end

  class EmptyArray < Node
    attr_accessor :size
    attr_accessor :component_type
    def initialize(parent, line_number, type, &block)
      super(parent, line_number, [])
      @component_type = type
      @size = size
      @inferred_type = Duby::AST::type(type.name, true)

      @size = yield(self)
    end

    def infer(typer)
      typer.infer(size)
      resolved!
      return @inferred_type
    end
  end
end