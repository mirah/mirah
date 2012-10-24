module Mirah
  module JVM
    module Types
      class BlockType < Type
        def initialize
          super(':block', nil)
        end

        def isBlock
          true
        end
      end
    end
  end
end
