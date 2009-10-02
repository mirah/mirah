module Duby
  module AST
    class Condition < Node
      attr_accessor :predicate

      def initialize(parent, line_number)
        @predicate = (children = yield(self))[0]
        super(parent, line_number, children)
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

      def initialize(parent, line_number)
        @condition, @body, @else = children = yield(self)
        super(parent, line_number, children)
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
      attr_accessor :condition, :body, :check_first, :negative

      def initialize(parent, line_number, check_first, negative)
        @condition, @body = children = yield(self)
        @check_first = check_first
        @negative = negative
        super(parent, line_number, children)
      end

      def check_first?; @check_first; end
      def negative?; @negative; end

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
      def initialize(parent, line_number)
        super(parent, line_number, yield(self))
      end
    end

    class Return < Node
      include Valued

      def initialize(parent, line_number)
        @value = (children = yield(self))[0]
        super(parent, line_number, children)
      end

      def infer(typer)
        unless resolved?
          @inferred_type = typer.infer(value)

          (@inferred_type && value.resolved?) ? resolved! : typer.defer(self)
        end

        @inferred_type
      end
    end

    class Break < Node;
      def infer(typer)
        unless resolved?
          resolved!
          @inferred_type = typer.null_type
        end
      end
    end
    
    class Next < Break; end
    
    class Redo < Break; end
  end
end