require 'bitescript'
require 'duby/ast'
require 'duby/jvm/method_lookup'
require 'duby/jvm/compiler'

module Duby
  module JVM
    module Types
      class Type < AST::TypeReference
        include Duby::JVM::MethodLookup

        attr_writer :inner_class

        def log(message)
          puts "* [JVM::Types] #{message}" if Duby::Compiler::JVM.verbose
        end

        def initialize(mirror_or_name)
          if mirror_or_name.kind_of?(BiteScript::ASM::ClassMirror)
            @type = mirror_or_name
            name = mirror_or_name.type.class_name
          else
            name = mirror_or_name.to_s
          end
          super(name, false, false)
          raise ArgumentError, "Bad type #{mirror_or_name}" if name =~ /Java::/
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

        def dynamic?
          false
        end

        def inner_class?
          @inner_class
        end

        def is_parent(other)
          assignable_from?(other)
        end

        def compatible?(other)
          assignable_from?(other)
        end

        def assignable_from?(other)
          return false if other.nil?
          return true if !primitive? && other == Null
          return true if other == self
          return true if other.error? || other.unreachable?

          # TODO should we allow more here?
          return interface? if other.block?

          return true if jvm_type && (jvm_type == other.jvm_type)

          assignable_from?(other.superclass) ||
              other.interfaces.any? {|i| assignable_from?(i)}
        end

        def iterable?
          ['java.lang.Iterable',
           'java.util.Iterator',
           'java.util.Enumeration'].any? {|n| AST.type(n).assignable_from(self)}
        end

        def component_type
          AST.type('java.lang.Object') if iterable?
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
          @array_type ||= Duby::JVM::Types::ArrayType.new(self)
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
          raise "Incomplete type #{self} (#{self.class})" unless jvm_type
          @interfaces ||= jvm_type.interfaces.map do |interface|
            AST.type(interface)
          end
        end

        def astore(builder)
          if primitive?
            builder.send "#{name[0,1]}astore"
          else
            builder.aastore
          end
        end

        def aload(builder)
          if primitive?
            builder.send "#{name[0,1]}aload"
          else
            builder.aaload
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
          widening_conversions = WIDENING_CONVERSIONS[self]
          widening_conversions && widening_conversions.include?(type)
        end

        def superclass
          nil
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

        def inner_class?
          basic_type.inner_class?
        end
      end

      class NullType < Type
        def initialize
          super('java.lang.Object')
        end

        def to_s
          "Type(null)"
        end

        def compatible?(other)
          !other.primitive?
        end
      end

      class VoidType < PrimitiveType
        def initialize
          super('void', Java::JavaLang::Void)
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
          Object
        end

        def interfaces
          []
        end
      end

      class DynamicType < Type
        ObjectType = Type.new('java.lang.Object')

        def initialize
          # For naming, bytecode purposes, we are an Object
          @name = "java.lang.Object"
        end

        def basic_type
          self
        end

        def is_parent(other)
          ObjectType.assignable_from?(other)
        end

        def assignable_from?(other)
          ObjectType.assignable_from?(other)
        end

        def jvm_type
          java.lang.Object
        end

        def dynamic?
          true
        end
      end

      class TypeDefinition < Type
        attr_accessor :node

        def initialize(name, node)
          raise ArgumentError, "Bad name #{name}" if name[0,1] == '.'
          @name = name
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
          class_name = @name.tr('.', '/')
          @type ||= builder.public_interface(class_name, *interfaces)
        end

        def interface?
          true
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