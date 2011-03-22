module Mirah
  module JVM
    module Types
      class ArrayType < Type
        attr_reader :component_type

        def initialize(component_type)
          @component_type = component_type
          if @component_type.jvm_type
            #@type = java.lang.reflect.Array.newInstance(@component_type.jvm_type, 0).class
          else
            # FIXME: THIS IS WRONG, but I don't know how to fix it
            #@type = @component_type
          end
          @name = component_type.name
        end

        def array?
          true
        end

        def iterable?
          true
        end

        def inner_class?
          basic_type.inner_class?
        end

        def basic_type
          component_type.basic_type
        end

        def superclass
          if component_type.primitive?
            Object
          elsif component_type.array?
            # fix covariance here for arrays of arrays
            # see #55
            Object
          else
            if component_type == Object
              Object
            else
              component_type.superclass.array_type
            end
          end
        end

        def interfaces
          []
        end

        def meta
          @meta ||= ArrayMetaType.new(self)
        end
      end

      class ArrayMetaType < MetaType; end
    end
  end
end