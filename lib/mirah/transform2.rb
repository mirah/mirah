module Duby::AST
  class TransformHelper
    def initialize(transformer)
      @mirah = transformer
    end

    def position(node)
      @mirah.position(node)
    end

    def transform_script(node, parent)
      Script.new(parent, position(node)) {|script| [@mirah.transform(node.children[0], script)]}
    end

    def transform_fixnum(node, parent)
      Duby::AST::fixnum(parent, position(node), node[1])
    end
  end
end