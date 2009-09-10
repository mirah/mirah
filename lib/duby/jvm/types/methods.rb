require 'duby/jvm/types'

java.lang.reflect.Member.class_eval do
  def static?
    java.lang.reflect.Modifier.static?(modifiers)
  end
end

module Duby::JVM::Types
  AST ||= Duby::AST

  class Intrinsic
    attr_reader :name, :argument_types, :type

    def initialize(klass, name, args, type, &block)
      raise ArgumentError, "Block required" unless block_given?
      @class = klass
      @name = name
      @argument_types = args
      @type = type
      @block = block
    end

    def call(builder, ast, expression)
      @block.call(builder, ast, expression)
    end
    
    def declaring_class
      @class
    end
  end
  
  class JavaConstructor
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
    
    def declaring_class
      AST.type(@member.declaring_class)
    end
    
    def call(compiler, ast, expression)
      return unless expression
      target = ast.target.inferred_type
      compiler.method.new target
      compiler.method.dup
      ast.parameters.each {|param| param.compile(compiler, true)}
      compiler.method.invokespecial(
        target,
        "<init>",
        [nil, *@member.argument_types])        
    end
  end

  class JavaMethod < JavaConstructor
    def return_type
      @return_type ||= begin
        type = AST.type(@member.return_type)
        type = declaring_class if type == Void
        type
      end
    end
    
    def static?
      @member.static?
    end
    
    def void?
      @member.return_type.nil?
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
      
      ast.parameters.each {|param| param.compile(compiler, true)}
      if target.interface?
        compiler.method.invokeinterface(
          target,
          ast.name,
          [ast.inferred_type, *@member.argument_types])
      else
        compiler.method.invokevirtual(
          target,
          ast.name,
          [ast.inferred_type, *@member.argument_types])
      end
      
      unless expression || void?
        compiler.method.pop
      end
    end
  end
  
  class JavaStaticMethod < JavaMethod
    def return_type
      @return_type ||= begin
        type = AST.type(@member.return_type)
        type = Null if type == Void
        type
      end
    end

    def call(compiler, ast, expression)
      target = ast.target.inferred_type
      ast.parameters.each {|param| param.compile(compiler, true)}
      compiler.method.invokestatic(
        target,
        ast.name,
        [ast.inferred_type, *@member.argument_types])
      # if expression, void static methods return null, for consistency
      # TODO: inference phase needs to track that signature is void
      # but actual type is null object
      compiler.method.aconst_null if expression && void?
      compiler.method.pop unless expression || void?
    end
  end
  
  class Type
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
  end
end