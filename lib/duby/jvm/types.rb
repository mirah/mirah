require 'bitescript'
require 'duby/ast'
require 'duby/jvm/method_lookup'

class Object
  def class_builder?
    self.class.name =~ /::ClassBuilder$/
  end
end

module Duby
  module JVM
    module Types
      class Type < AST::TypeReference
        include Duby::JVM::MethodLookup

        def initialize(java_type)
          orig_type = java_type
          if !(java_type.kind_of?(Java::JavaClass) ||
               java_type.class_builder?)
            java_type = java_type.java_class
          end
          super(java_type.name, false, false)
          raise ArgumentError, "Bad type #{orig_type}" if name =~ /Java::/
          @type = java_type
        end

        def jvm_type
          @type
        end

        def void?
          false
        end

        def meta?
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
        
        def is_parent(other)
          assignable_from?(other)
        end
        
        def compatible?(other)
          assignable_from?(other)
        end
        
        def assignable_from?(other)
          return true if !primitive? && other == Null
          return true if other == self
          return true if other.error? || other.unreachable?
          begin
            jvm_type.assignable_from?(other.jvm_type)
          rescue
            assignable_from?(other.superclass) ||
                other.interfaces.any? {|i| assignable_from?(i)}
          end
        end

        def meta
          @meta ||= MetaType.new(self)
        end
        
        def unmeta
          self
        end

        def basic_type
          self
        end

        def array_type
          @array_type ||= ArrayType.new(self)
        end

        def prefix
          'a'
        end
        
        # is this a 64 bit type?
        def wide?
          false
        end

        def inspect(indent=0)
          "#{' ' * indent}#<#{self.class.name} #{name}>"
        end

        def newarray(method)
          method.anewarray(self)
        end

        def superclass
          raise "Incomplete type #{self}" unless jvm_type
          AST.type(jvm_type.superclass) if jvm_type.superclass
        end
        
        def interfaces
          @interfaces ||= jvm_type.interfaces.map do |interface|
            AST.type(interface)
          end
        end
      end

      class PrimitiveType < Type
        def initialize(type, wrapper)
          @wrapper = wrapper
          super(type)
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
        
        def interfaces
          []
        end
        
        def convertible_to?(type)
          return true if type == self
          a, b = TYPE_ORDERING.index(self), TYPE_ORDERING.index(type)
          a && b && b > a
        end
      end
      
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
      end
      
      class NullType < Type
        def initialize
          super(java.lang.Object)
        end
        
        def compatible?(other)
          !other.primitive?
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
        
        def return(builder)
          builder.returnvoid
        end
      end

      class ArrayType < Type
        attr_reader :component_type

        def initialize(component_type)
          @component_type = component_type
          @name = component_type.name
        end

        def jvm_type
          @component_type.jvm_type
        end

        def array?
          true
        end
        
        def basic_type
          component_type.basic_type
        end
        
        def superclass
          Object
        end
      end
      
      class TypeDefinition < Type
        attr_accessor :node
        
        def initialize(name, node)
          if name.class_builder?
            super(name)
          else
            raise ArgumentError, "Bad name #{name}" if name[0,1] == '.'
            @name = name
          end
          @node = node
          raise ArgumentError, "Bad type #{name}" if self.name =~ /Java::/
        end
        
        def name
          if @type
            @type.name
          else
            @name
          end
        end
        
        def superclass
          (node && node.superclass) || Object
        end
        
        def interfaces
          if node
            node.interfaces
          else
            []
          end
        end
        
        def define(builder)
          class_name = @name.tr('.', '/')
          @type ||= builder.public_class(class_name, superclass, *interfaces)
        end
        
        def meta
          @meta ||= TypeDefMeta.new(self)
        end
      end
      
      class InterfaceDefinition < TypeDefinition
        def initialize(name, node)
          super(name, node)
        end
        
        def define(builder)
          @type ||= builder.public_interface(@name, *interfaces)
        end
      end
      
      class TypeDefMeta < MetaType
      end
    end
  end
end

require 'duby/jvm/types/intrinsics'
require 'duby/jvm/types/methods'
require 'duby/jvm/types/number'
require 'duby/jvm/types/integers'
require 'duby/jvm/types/boolean'
require 'duby/jvm/types/floats'
require 'duby/jvm/types/basic_types'
require 'duby/jvm/types/literals'