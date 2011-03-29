# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mirah
  module AST
    class Condition < Node
      child :predicate

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end

      def infer(typer, expression)
        unless resolved?
          @inferred_type = typer.infer(predicate, true)
          if @inferred_type && !@inferred_type.primitive?
            call = Call.new(parent, position, '!=') do |call|
              predicate.parent = call
              [predicate, [Null.new(call, position)]]
            end
            self.predicate = call
            @inferred_type = typer.infer(predicate, true)
          end

          @inferred_type ? resolved! : typer.defer(self)
        end

        @inferred_type
      end
    end

    class If < Node
      child :condition
      child :body
      child :else

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end

      def infer(typer, expression)
        unless resolved?
          condition_type = typer.infer(condition, true)
          unless condition_type
            typer.defer(condition)
          end

          # condition type is unrelated to body types, so we proceed with bodies
          then_type = typer.infer(body, expression) if body
          else_type = typer.infer(self.else, expression) if self.else

          if expression
            have_body_type = body.nil? || then_type
            have_else_type = self.else.nil? || else_type
            if have_body_type && have_else_type
              if then_type && else_type
                # both then and else inferred, ensure they're compatible
                if then_type.compatible?(else_type)
                  # types are compatible...if condition is resolved, we're done
                  @inferred_type = then_type.narrow(else_type)
                  resolved! if condition_type
                else
                  raise Mirah::Typer::InferenceError.new("if statement with incompatible result types #{then_type} and #{else_type}")
                end
              else
                @inferred_type = then_type || else_type
                resolved!
              end
            else
              typer.defer(self)
            end
          else
            @inferred_type = typer.no_type
            resolved!
          end
        end

        @inferred_type
      end
    end

    class Loop < Node
      child :init
      child :condition
      child :pre
      child :body
      child :post
      attr_accessor :check_first, :negative, :redo

      def initialize(parent, position, check_first, negative, &block)
        @check_first = check_first
        @negative = negative

        @children = [
            Body.new(self, position),
            nil,
            Body.new(self, position),
            nil,
            Body.new(self, position),
        ]
        super(parent, position) do |l|
          condition, body = yield(l)
          [self.init, condition, self.pre, body, self.post]
        end
      end

      def infer(typer, expression)
        unless resolved?
          child_types = children.map do |c|
            if c.nil? || (Body === c && c.empty?)
              typer.no_type
            else
              typer.infer(c, true)
            end
          end
          if child_types.any? {|t| t.nil?}
            typer.defer(self)
          else
            resolved!
            @inferred_type = typer.null_type
          end
        end

        @inferred_type
      end

      def check_first?; @check_first; end
      def negative?; @negative; end

      def redo?
        if @redo.nil?
          nodes = @children.dup
          until nodes.empty?
            node = nodes.shift
            while node.respond_to?(:inlined) && node.inlined
              node = node.inlined
            end
            next if node.nil? || Loop === node
            if Redo === node
              return @redo = true
            end
            nodes.insert(-1, *node.children.flatten)
          end
          return @redo = false
        else
          @redo
        end
      end

      def init?
        init && !(init.kind_of?(Body) && init.empty?)
      end

      def pre?
        pre && !(pre.kind_of?(Body) && pre.empty?)
      end

      def post?
        post && !(post.kind_of?(Body) && post.empty?)
      end

      def to_s
        "Loop(check_first = #{check_first?}, negative = #{negative?})"
      end
    end

    class Not < Node
      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end
    end

    class Return < Node
      include Valued

      child :value

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end

      def infer(typer, expression)
        resolve_if(typer) do
          if value
            typer.infer(value, true)
          else
            typer.no_type
          end
        end
      end
    end

    class Break < Node;
      def infer(typer, expression)
        unless resolved?
          resolved!
          @inferred_type = typer.null_type
        end
        @inferred_type
      end
    end

    class Next < Break; end

    class Redo < Break; end

    class Raise < Node
      include Valued

      child :exception

      def initialize(parent, line_number, &block)
        super(parent, line_number, &block)
      end

      def infer(typer, expression)
        unless resolved?
          @inferred_type = AST.unreachable_type
          throwable = AST.type(nil, 'java.lang.Throwable')
          if children.size == 1
            arg_type = typer.infer(self.exception, true)
            unless arg_type
              typer.defer(self)
              return
            end
            if throwable.assignable_from?(arg_type) && !arg_type.meta?
              resolved!
              return @inferred_type
            end
          end

          arg_types = children.map {|c| typer.infer(c, true)}
          if arg_types.any? {|c| c.nil?}
            typer.defer(self)
          else
            if arg_types[0] && throwable.assignable_from?(arg_types[0])
              klass = children.shift
            else
              klass = Constant.new(self, position, 'RuntimeException')
            end
            exception = Call.new(self, position, 'new') do
              [klass, children, nil]
            end
            resolved!
            @children = [exception]
            typer.infer(exception, true)
          end
        end
        @inferred_type
      end
    end

    defmacro('raise') do |transformer, fcall, parent|
      Raise.new(parent, fcall.position) do |raise_node|
        fcall.parameters
      end
    end

    class RescueClause < Node
      attr_accessor :name, :type, :types
      child :type_nodes
      child :body

      def initialize(parent, position)
        super(parent, position) do
          yield(self) if block_given?
        end
      end

      def infer(typer, expression)
        unless resolved?
          static_scope = typer.add_scope(self)
          static_scope.parent = typer.get_scope(self)
          @types ||= type_nodes.map {|n| n.type_reference(typer)}
          if name
            static_scope.shadow(name)
            # TODO find the common parent Throwable
            @type = types.size == 1 ? types[0] : AST.type(nil, 'java.lang.Throwable')
            typer.learn_local_type(static_scope, name, @type)
          end
          @inferred_type = typer.infer(body, true)

          (@inferred_type && body.resolved?) ? resolved! : typer.defer(self)
        end

        @inferred_type
      end
    end

    class Rescue < Node
      child :body
      child :clauses
      def initialize(parent, position, &block)
        super(parent, position, &block)
        @body, @clauses = children
      end

      def infer(typer, expression)
        unless resolved?
          types = [typer.infer(body, true )] + clauses.map {|c| typer.infer(c, true)}
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
      child :body
      child :clause
      attr_accessor :state  # Used by some compilers.

      def initialize(parent, position, &block)
        super(parent, position, &block)
      end

      def infer(typer, expression)
        resolve_if(typer) do
          typer.infer(clause, false)
          typer.infer(body, true)
        end
      end
    end
  end
end