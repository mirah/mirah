require 'bitescript'
require 'duby/ast'
require 'duby/jvm/method_lookup'
require 'duby/jvm/methods'

module Duby
  module JVM
    module Types
      class Type < AST::TypeReference
        include Duby::JVM::MethodLookup

        def initialize(java_type)
          if !(java_type.kind_of?(Java::JavaClass) ||
               java_type.kind_of?(BiteScript::ClassBuilder))
            java_type = java_type.java_class
          end
          super(java_type.name, false, false)
          @type = java_type
          raise ArgumentError if @name == 'boolean' && !(primitive?||array?)
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

        def meta
          @meta ||= MetaType.new(self)
        end

        def basic_type
          self
        end

        def array_type
          @array_type ||= ArrayType.new(self)
        end

        def inspect(indent=0)
          "#{' ' * indent}#<#{self.class.name} #{name}>"
        end

        def newarray(method)
          method.anewarray(self)
        end

        def intrinsics
          @intrinsics ||= Hash.new {|h, k| h[k] = {}}
        end

        def get_method(name, args)
          find_method(self, name, args, meta?)
        end
        
        def constructor(*types)
          types = types.map {|type| type.jvm_type}
          constructor = (jvm_type.constructor(*types) rescue nil)
          return JavaConstructor.new(constructor) if constructor
          raise NameError, "No constructor #{name}(#{types.join ', '})"
        end
        
        def java_method(name, *types)
          intrinsic = intrinsics[name][types]
          return intrinsic if intrinsic
          types = types.map {|type| type.jvm_type}
          method = (jvm_type.java_method(name, *types) rescue nil)
          if method && method.static? == meta?
            return JavaStaticMethod.new(method) if method.static?
            return JavaMethod.new(method)
          end
          raise NameError, "No method #{self.name}.#{name}(#{types.join ', '})"
        end

        def add_method(name, args, method_or_type=nil, &block)
          if block_given?
            method_or_type = Intrinsic.new(self, name, args,
                                           method_or_type, &block)
          end
          intrinsics[name][args] = method_or_type
        end

        def declared_intrinsics
          methods = []
          intrinsics.each do |name, group|
            group.each do |args, method|
              methods << method
            end
          end
          methods
        end

        def declared_instance_methods
          methods = jvm_type.declared_instance_methods.map do |method|
            JavaMethod.new(method)
          end
          methods.concat(basic_type.declared_intrinsics)
        end

        def declared_class_methods
          methods = jvm_type.declared_class_methods.map do |method|
            JavaStaticMethod.new(method)
          end
          methods.concat(meta.declared_intrinsics)
        end

        def superclass
          AST.type(jvm_type.superclass) if jvm_type.superclass
        end

        def ==(other)
          self.class == other.class && super
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
        
        def jvm_type
          unmeta.jvm_type
        end
      end
      
      class NullType < Type
        def initialize
          @name = 'null'
          @type = nil
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
      end

      class ArrayType < Type
        attr_reader :component_type

        def initialize(component_type)
          super(component_type.jvm_type)
          @component_type = component_type

          add_method(
              '[]', [Int], component_type) do |compiler, call, expression|
            if expression
              call.target.compile(compiler, true)
              call.parameters[0].compile(compiler, true)
              if component_type.primitive?
                compiler.method.send "#{name[0,1]}aload"
              else
                compiler.method.aaload
              end
            end
          end

          add_method('[]=',
                     [Int, component_type],
                     component_type) do |compiler, call, expression| 
            call.target.compile(compiler, true)
            call.parameters[0].compile(compiler, true)
            call.parameters[1].compile(compiler, true)
            if component_type.primitive?
              compiler.method.send "#{name[0,1]}astore"
            else
              compiler.method.aastore
            end
            if expression
              call.parameters[1].compile(compiler, true)
            end
          end
          
          add_method('length', [], Int) do |compiler, call, expression|
            call.target.compile(compiler, true)
            compiler.method.arraylength              
          end
        end

        def array?
          true
        end
        
        def basic_type
          component_type.basic_type
        end
      end
      
      class TypeDefinition < Type
        attr_reader :superclass
        
        def initialize(name, superclass)
          if name.kind_of? BiteScript::ClassBuilder
            super(name)
          else
            @name = name
          end
          @superclass = superclass
        end
        
        def define(builder)
          @type = builder.public_class(@name)
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

      Object = Type.new(Java::JavaLang.Object)
      String = Type.new(Java::JavaLang.String)        

      Void = VoidType.new
      Null = NullType.new
    end
  end
end