module Mirah
  module JVM
    module Types
      class MetaType < Type
        attr_reader :unmeta

        def initialize(unmeta)
          @name = unmeta.name
          @unmeta = unmeta
        end

        def basic_type
          @unmeta.basic_type
        end

        def meta?
          true
        end

        def meta
          self
        end

        def superclass
          @unmeta.superclass.meta if @unmeta.superclass
        end

        def interfaces
          []
        end

        def jvm_type
          unmeta.jvm_type
        end

        def inner_class?
          basic_type.inner_class?
        end
      end

      class TypeDefMeta < MetaType
      end
    end
  end
end