module Duby::AST
  class Arguments < Node
    attr_accessor :args, :opt_args, :rest_arg, :block_arg
    
    def initialize(parent, line_number)
      @args, @opt_args, @rest_arg, @block_arg = children = yield(self)
      super(parent, line_number, children)
    end
    
    def infer(typer)
      unless @inferred_type
        @inferred_type = args ? args.map {|arg| arg.infer(typer)} : []
      end
    end
  end
      
  class Argument < Node
    include Typed
  end
      
  class RequiredArgument < Argument
    include Named
    include Scoped
    
    def initialize(parent, line_number, name)
      super(parent, line_number)

      @name = name
    end
    
    def infer(typer)
      unless @inferred_type
        # if not already typed, check parent of parent (MethodDefinition) for signature info
        method_def = parent.parent
        signature = method_def.signature

        # if signature, search for this argument
        if signature[name.intern]
          @inferred_type = typer.learn_local_type(scope, name, signature[name.intern])
        else
          @inferred_type = typer.local_type(scope, name)
        end
          
        unless @inferred_type
          typer.defer(self)
        end
      end
        
      @inferred_type
    end
  end
      
  class OptionalArgument < Argument
    include Named
    include Scoped
    attr_accessor :child
    
    def initialize(parent, line_number)
      @child = (children = yield(self))[0]
      @name = @child.name
      super(parent, line_number, children)
    end
  end
      
  class RestArgument < Argument
    include Named
    include Scoped
    
    def initialize(parent, line_number, name)
      super(parent, line_number)

      @name = name
    end
  end
      
  class BlockArgument < Argument
    include Named
    
    def initialize(parent, line_number, name)
      super(parent, line_number)

      @name = name
    end
  end
      
  class MethodDefinition < Node
    include Named
    include Scope
    attr_accessor :signature, :arguments, :body
        
    def initialize(parent, line_number, name)
      super(parent, line_number, yield(self))
      @signature, @arguments, @body = children
      @name = name
    end
        
    def infer(typer)
      typer.infer_signature(self)
      arguments.infer(typer)
      forced_type = signature[:return]
      inferred_type = body ? body.infer(typer) : typer.no_type
        
      if !inferred_type
        typer.defer(self)
      else
        actual_type = if forced_type.nil?
          inferred_type
        elsif inferred_type == typer.null_type
          forced_type
        elsif forced_type == typer.no_type
          # If the parent method is void we have to return void.
          forced_type
        else
          inferred_type
        end
        
        if forced_type && forced_type != typer.no_type && !forced_type.is_parent(actual_type)
          raise Duby::Typer::InferenceError.new("Inferred return type #{actual_type} is incompatible with declared #{forced_type}", self)
        end
        

        @inferred_type = typer.learn_method_type(typer.self_type, name, arguments.inferred_type, actual_type)
        signature[:return] = @inferred_type
      end
        
      @inferred_type
    end
  end
      
  class StaticMethodDefinition < MethodDefinition
  end
end