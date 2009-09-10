module Duby::JVM::Types
  class Type
    def intrinsics
      @intrinsics ||= Hash.new {|h, k| h[k] = {}}
    end
    
    def add_intrinsics
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
  end
  
  class ArrayType
    def add_intrinsics
      super
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
  end
end