module Duby
  module AST
    class Condition < Node
      attr_accessor :predicate

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
        @predicate = children[0]
      end

      def infer(typer)
        unless resolved?
          @inferred_type = typer.infer(predicate)

          @inferred_type ? resolved! : typer.defer(self)
        end

        @inferred_type
      end
    end

    class If < Node
      attr_accessor :condition, :body, :else

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
        @condition, @body, @else = children
      end

      def infer(typer)
        unless resolved?
          condition_type = typer.infer(condition)
          unless condition_type
            typer.defer(condition)
          end

          # condition type is unrelated to body types, so we proceed with bodies
          then_type = typer.infer(body) if body

          if !then_type
            # attempt to determine else branch
            if self.else
              else_type = typer.infer(self.else)

              if !else_type
                # we have neither type, defer until later
                typer.defer(self)
              else
                # we have else but not then, defer only then and use else type for now
                @inferred_type = else_type
                typer.defer(self)
              end
            else
              # no then type could be inferred and no else body, defer for now
              typer.defer(self)
            end
          else
            if self.else
              else_type = typer.infer(self.else)

              if !else_type
                # we determined a then type, so we use that and defer the else body
                @inferred_type = then_type
                typer.defer(self)
              else
                # both then and else inferred, ensure they're compatible
                if then_type.compatible?(else_type)
                  # types are compatible...if condition is resolved, we're done
                  @inferred_type = then_type.narrow(else_type)
                  resolved! if condition_type
                else
                  raise Typer::InferenceError.new("if statement with incompatible result types")
                end
              end
            else
              # only then and type inferred, we're 100% resolved
              @inferred_type = then_type
              resolved! if condition_type
            end
          end
        end

        @inferred_type
      end
    end

    class Loop < Node
      attr_accessor :condition, :body, :check_first, :negative, :redo

      def initialize(parent, line_number, check_first, negative, &block)
        super(parent, line_number, children, &block)
        @condition, @body = children
        @check_first = check_first
        @negative = negative
      end

      def check_first?; @check_first; end
      def negative?; @negative; end
      def has_redo?; @redo; end

      def to_s
        "Loop(check_first = #{check_first?}, negative = #{negative?})"
      end
      
      def infer(typer)
        unless resolved?
          typer.infer(body)
          
          typer.infer(condition)
          
          if body.resolved? && condition.resolved?
            resolved!
          else
            typer.defer(self)
          end
        end
        
        typer.null_type
      end
    end

    class Not < Node
      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end
    end

    class JumpNode < Node
      attr_accessor :ensures
      
      def initialize(parent, line_number, ensures, &block)
        super(parent, line_number, &block)
        @ensures = ensures
      end
    end

    class Return < JumpNode
      include Valued

      def initialize(parent, line_number, ensures, &block)
        super(parent, line_number, ensures, &block)
        @value = children[0]
      end

      def infer(typer)
        unless resolved?
          @inferred_type = typer.infer(value)

          (@inferred_type && value.resolved?) ? resolved! : typer.defer(self)
        end

        @inferred_type
      end
    end

    class Break < JumpNode;
      def infer(typer)
        unless resolved?
          resolved!
          @inferred_type = typer.null_type
        end
      end
    end
    
    class Next < Break; end
    
    class Redo < Break; end

    class Raise < Node
      include Valued

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end

      def infer(typer)
        unless resolved?
          @inferred_type = AST.unreachable_type
          throwable = AST.type('java.lang.Throwable')
          if children.size == 1
            arg_type = typer.infer(children[0])
            unless arg_type
              typer.defer(self)
              return
            end
            if throwable.assignable_from?(arg_type) && !arg_type.meta?
              @exception = children[0]
              resolved!
              return @inferred_type
            end
          end

          arg_types = children.map {|c| typer.infer(c)}
          if arg_types.any? {|c| c.nil?}
            typer.defer(self)
          else
            if arg_types[0] && throwable.assignable_from?(arg_types[0])
              klass = children.shift
            else
              klass = Constant.new(self, position, 'RuntimeException')
            end
            @exception = Call.new(self, position, 'new') do
              [klass, children, nil]
            end
            resolved!
            @children = [@exception]
            typer.infer(@exception)
          end
        end
        @inferred_type
      end
    end
    
    class RescueClause < Node
      include Scoped
      attr_accessor :types, :body, :name, :type
      
      def initialize(parent, position, &block)
        super(parent, position, &block)
        @types, @body = children
      end

      def infer(typer)
        unless resolved?
          if name
            orig_type = typer.local_type(scope, name)
            # TODO find the common parent Throwable
            @type = types.size == 1 ? types[0] : AST.type('java.lang.Throwable')
            typer.learn_local_type(scope, name, @type)
          end
          @inferred_type = typer.infer(body)

          (@inferred_type && body.resolved?) ? resolved! : typer.defer(self)
          typer.local_type_hash(scope)[name] = orig_type if name
        end

        @inferred_type
      end
    end
    
    class Rescue < Node
      attr_accessor :body, :clauses
      def initialize(parent, position, &block)
        super(parent, position, &block)
        @body, @clauses = children
      end
      
      def infer(typer)
        unless resolved?
          types = [typer.infer(body)] + clauses.map {|c| typer.infer(c)}
          if types.any? {|t| t.nil?}
            typer.defer(self)
          else
            # TODO check types for compatibility (maybe only if an expression)
            resolved!
            @inferred_type = types[0]
          end
        end
        @inferred_type
      end
    end
    
    class Ensure < Node
      attr_reader :body, :clause
      attr_accessor :state  # Used by the some compilers.
      
      def initialize(parent, position, &block)
        super(parent, position, &block)
        @body, @clause = children
      end
      
      def infer(typer)
        resolve_if(typer) do
          typer.infer(clause)
          typer.infer(body)
        end
      end
      
      def ensures
        [self]
      end
    end
  end
end