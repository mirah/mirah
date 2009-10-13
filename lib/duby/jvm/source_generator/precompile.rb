require 'duby/ast'

module Duby::AST
  class TempValue
    def initialize(node, compiler=nil, value=nil)
      if compiler.nil?
        @tempname = node
      else
        @tempname = compiler.temp(node, value)
        @tempvalue = value || node
      end
    end
    
    def compile(compiler, expression)
      if expression
        compiler.method.print @tempname
      end
    end
    
    def reload(compiler)
      compiler.assign(@tempname, @tempvalue)
    end
  end
  
  class Node
    def expr?(compiler)
      true
    end

    def precompile(compiler)
      if expr?(compiler)
        self
      else
        temp(compiler)
      end
    end
    
    def temp(compiler, value=nil)
      TempValue.new(self, compiler, value)
    end
  end
  
  class Body
    def expr?(compiler)
      false
    end
  end
  
  class If
    def expr?(compiler)
      return false unless condition.predicate.expr?(compiler)
      return false unless body.nil? || body.expr?(compiler)
      return false unless self.else.nil? || self.else.expr?(compiler)
      true
    end
  end
  
  class Loop
    def expr?(compiler)
      false
    end
    
    def precompile(compiler)
      compile(compiler, false)
      temp(compiler, 'null')
    end
  end
  
  class Call
    def method(compiler=nil)
      @method ||= begin
        arg_types = parameters.map {|p| p.inferred_type}
        target.inferred_type.get_method(name, arg_types)
      end
    end
    
    def expr?(compiler)
      target.expr?(compiler) &&
          parameters.all? {|p| p.expr?(compiler)} &&
          !method.actual_return_type.void?
    end
  end
  
  class FunctionalCall
    def method(compiler)
      @method ||= begin
        arg_types = parameters.map {|p| p.inferred_type}
        compiler.self_type.get_method(name, arg_types)
      end
    end
    
    def expr?(compiler)
      parameters.all? {|p| p.expr?(compiler)} &&
          (cast? || !method(compiler).actual_return_type.void?)
    end
  end
  
  class EmtpyArray
    def expr?(compiler)
      size.expr?(compiler)
    end
  end
  
  class LocalAssignment
    def expr?(compiler)
      compiler.method.local?(name) && value.expr?(compiler)
    end

    def precompile(compiler)
      if expr?(compiler)
        self
      else
        compile(compiler, false)
        TempValue.new(name)
      end
    end
  end
  
  class Return
    def expr?(compiler)
      false
    end
  end
  
  class Raise
    def expr(compiler)
      false
    end
  end
  
  class Rescue
    def expr(compiler)
      false
    end
  end
end