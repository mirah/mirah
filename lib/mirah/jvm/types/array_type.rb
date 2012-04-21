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
          @type_system = component_type.type_system
          self.intrinsics
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
          object_type = @type_system.type(nil, 'java.lang.Object')
          if component_type.primitive?
            object_type
          elsif component_type.array?
            # fix covariance here for arrays of arrays
            # see #55
            object_type
          else
            if component_type == object_type
              object_type
            else
              component_type.superclass.array_type
            end
          end
        end

        def interfaces(include_parent=true)
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