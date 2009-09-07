require 'bitescript'

module Duby
  module Compiler
    class JVM
      module Types
        class Type
          attr_reader :name

          def initialize(java_type)
            if !(java_type.kind_of?(Java::JavaClass) ||
                 java_type.kind_of?(BiteScript::ClassBuilder))
              java_type = java_type.java_class
            end
            @name = java_type.name
            @type = java_type
            raise ArgumentError if @name == 'boolean' && !(primitive?||array?)
          end

          def jvm_type
            @type
          end

          def void?
            false
          end

          def array?
            false
          end

          def primitive?
            false
          end

          def interface?
            @type.interface?
          end

          def array_type
            @array_type ||= ArrayType.new(self)
          end

          def inspect
            "#<#{self.class.name} #{name}>"
          end

          def newarray(method)
            method.anewarray(self)
          end
        end
        
        class PrimitiveType < Type
          def initialize(type, wrapper)
            super(type)
            @wrapper = wrapper
          end
          
          def primitive?
            true
          end
          
          def primitive_type
            @wrapper::TYPE
          end

          def newarray(method)
            method.send "new#{name}array"
          end
        end
        
        class VoidType < PrimitiveType
          def initialize
            super(Java::JavaLang::Void, Java::JavaLang::Void)
            @name = "void"
          end
          
          def void?
            true
          end
        end
        
        class ArrayType < Type
          attr_reader :component_type
          
          def initialize(component_type)
            super(component_type.jvm_type)
            @component_type = component_type
          end
          
          def array?
            true
          end
        end

        Boolean = PrimitiveType.new(Java::boolean, java.lang.Boolean)
        Byte = PrimitiveType.new(Java::byte, java.lang.Byte)
        Char = PrimitiveType.new(Java::char, java.lang.Character)
        Short = PrimitiveType.new(Java::short, java.lang.Short)
        Int = PrimitiveType.new(Java::int, java.lang.Integer)
        Long = PrimitiveType.new(Java::long, java.lang.Long)
        Float = PrimitiveType.new(Java::float, java.lang.Float)
        Double = PrimitiveType.new(Java::double, java.lang.Double)
        
        Void = VoidType.new

        Object = Type.new(Java::JavaLang.Object)
        String = Type.new(Java::JavaLang.String)        
      end
    end
  end
end