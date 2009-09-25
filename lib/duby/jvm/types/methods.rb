require 'duby/jvm/types'

class Java::JavaMethod
  def static?
    java.lang.reflect.Modifier.static?(modifiers)
  end
end

module Duby::JVM::Types
  AST ||= Duby::AST

  module ArgumentConversion
    def convert_args(compiler, values, types=nil)
      # TODO boxing/unboxing
      # TODO varargs
      types ||= argument_types
      values.zip(types).each do |value, type|
        value.compile(compiler, true)
        if type.primitive? && type != value.inferred_type
            value.inferred_type.widen(compiler.method, type)
        end
      end
    end
  end
  
  Type.send :include, ArgumentConversion

  class Intrinsic
    include ArgumentConversion
    attr_reader :name, :argument_types, :return_type

    def initialize(klass, name, args, type, &block)
      raise ArgumentError, "Block required" unless block_given?
      @class = klass
      @name = name
      @argument_types = args
      @return_type = type
      @block = block
    end

    def call(builder, ast, expression)
      @block.call(builder, ast, expression)
    end
    
    def declaring_class
      @class
    end
    
    def constructor?
      false
    end
    
    def actual_return_type
      return_type
    end
  end
  
  class JavaConstructor
    include ArgumentConversion
    def initialize(member)
      @member = member
    end

    def name
      @name ||= @member.name
    end
    
    def argument_types
      @argument_types ||= @member.argument_types.map do |arg|
        AST.type(arg)
      end
    end
    
    def return_type
      declaring_class
    end
    
    def actual_return_type
      return_type
    end

    def declaring_class
      AST.type(@member.declaring_class)
    end
    
    def call(compiler, ast, expression)
      target = ast.target.inferred_type
      compiler.method.new target
      compiler.method.dup if expression
      convert_args(compiler, ast.parameters)
      compiler.method.invokespecial(
        target,
        "<init>",
        [nil, *@member.argument_types])        
    end
    
    def constructor?
      true
    end
  end

  class JavaMethod < JavaConstructor
    def return_type
      @return_type ||= begin
        if @member.return_type
          AST.type(@member.return_type)
        else
          declaring_class
        end
      end
    end
    
    def actual_return_type
      if @member.return_type
        return_type
      else
        Void
      end
    end
    
    def static?
      @member.static?
    end
    
    def void?
      @member.return_type.nil?
    end
    
    def constructor?
      false
    end
    
    def call(compiler, ast, expression)
      target = ast.target.inferred_type
      ast.target.compile(compiler, true)
      
      # if expression, void methods return the called object,
      # for consistency and chaining
      # TODO: inference phase needs to track that signature is
      # void but actual type is callee
      if expression && void?
        compiler.method.dup
      end
      
      convert_args(compiler, ast.parameters)
      if target.interface?
        compiler.method.invokeinterface(
          target,
          name,
          [@member.return_type, *@member.argument_types])
      else
        compiler.method.invokevirtual(
          target,
          name,
          [@member.return_type, *@member.argument_types])
      end
      
      unless expression || void?
        compiler.method.pop
      end
    end
  end
  
  class JavaStaticMethod < JavaMethod
    def return_type
      @return_type ||= begin
        if @member.return_type
          AST.type(@member.return_type)
        else
          Void
        end
      end
    end

    def call(compiler, ast, expression)
      target = ast.target.inferred_type
      convert_args(compiler, ast.parameters)
      compiler.method.invokestatic(
        target,
        name,
        [@member.return_type, *@member.argument_types])
      # if expression, void static methods return null, for consistency
      # TODO: inference phase needs to track that signature is void
      # but actual type is null object
      compiler.method.aconst_null if expression && void?
      compiler.method.pop unless expression || void?
    end
  end
  
  class DubyMember
    attr_reader :name, :argument_types, :declaring_class, :return_type
    
    def initialize(klass, name, args, return_type, static)
      if return_type == Void
        return_type = nil
      end
      @declaring_class = klass
      @name = name
      @argument_types = args
      @return_type = return_type
      @static = static
    end
    
    def static?
      @static
    end
  end
  
  class Type
    def get_method(name, args)
      method = find_method(self, name, args, meta?)
      unless method
        # Allow constant narrowing for assignment methods
        if name =~ /=$/ && args[-1].respond_to?(:narrow!)
          if args[-1].narrow!
            method = find_method(self, name, args, meta?)
          end
        end 
      end
      method
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

    def declared_instance_methods
      methods = jvm_type.declared_instance_methods.map do |method|
        JavaMethod.new(method)
      end
      methods.concat((meta? ? unmeta : self).declared_intrinsics)
    end

    def declared_class_methods
      methods = jvm_type.declared_class_methods.map do |method|
        JavaStaticMethod.new(method)
      end
      methods.concat(meta.declared_intrinsics)
    end
  end

  class TypeDefinition
    def java_method(name, *types)
      method = instance_methods[name].find {|m| m.argument_types == types}
      return method if method
      raise NameError, "No method #{self.name}.#{name}(#{types.join ', '})"
    end
    
    def java_static_method(name, *types)
      method = static_methods[name].find {|m| m.argument_types == types}
      return method if method
      raise NameError, "No method #{self.name}.#{name}(#{types.join ', '})"
    end
    
    def constructor(*types)
      constructor = constructors.find {|c| c.argument_types == types}
      return constructor if constructor
      raise NameError, "No constructo #{name}(#{types.join ', '})"
    end

    def declared_instance_methods
      instance_methods.values.flatten
    end

    def declared_class_methods
      static_methods.values.flatten
    end
    
    def constructors
      @constructors ||= []
    end
    
    def instance_methods
      @instance_methods ||= Hash.new {|h, k| h[k] = []}
    end
    
    def static_methods
      @static_methods ||= Hash.new {|h, k| h[k] = []}
    end
    
    def declare_method(name, arguments, type)
      member = DubyMember.new(self, name, arguments, type, false)
      if name == 'initialize'
        constructors << JavaConstructor.new(member)
      else
        instance_methods[name] << JavaMethod.new(member)
      end
    end
    
    def declare_static_method(name, arguments, type)
      member = DubyMember.new(self, name, arguments, type, true)
      static_methods[name] << JavaStaticMethod.new(member)
    end
  end

  class TypeDefMeta
    def constructor(*args)
      unmeta.constructor(*args)
    end

    def java_method(*args)
      unmeta.java_static_method(*args)
    end
    
    def declared_instance_methods
      unmeta.declared_instance_methods
    end
    
    def declared_class_methods
      unmeta.declared_class_methods
    end
  end
end