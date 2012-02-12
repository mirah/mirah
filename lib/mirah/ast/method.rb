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

module Mirah::AST
  class Arguments < Node
    child :required
    child :opt_args
    child :rest_arg
    child :required2
    child :block_arg

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer, expression)
      unless resolved?
        @inferred_type = args ? args.map {|arg| typer.infer(arg, true)} : []
        if @inferred_type.all?
          resolved!
        else
          typer.defer(self)
        end
      end
      @inferred_type
    end

    def arg_types_match(arg_node, child_index)
      if RequiredArgument == arg_node && (child_index == 0 || child_index == 3)
        return true
      else
        return OptionalArgument == arg_node && child_index == 1
      end
    end

    def validate_child(args, child_index)
      if args.kind_of?(::Array)
        args.each_with_index do |arg, arg_index|
          if UnquotedValue === arg
            actual_arg = arg.f_arg
            if arg_types_match(actual_arg, child_index)
              args[arg_index] = actual_arg
              actual_arg.parent = self
            else
              args[arg_index, 1] = []
              merge_args(actual_arg, child_index)
            end
          end
        end
      elsif UnquotedValue == args
        @children[child_index] = nil
        merge_args(args.f_arg, child_index)
      end
    end

    def merge_args(args, child_index)
      args.parent = self if Argument === args
      case args
      when Arguments
        args.children.each_with_index {|child, i| merge_args(child, i)}
      when ::Array
        args.each {|arg| merge_args(arg, child_index)}
      when RequiredArgument
        if child_index > 2
          self.required2 << args
        else
          self.required << args
        end
      when OptionalArgument
        self.opt_args << args
      when RestArgument
        raise "Multiple rest args" unless rest_arg.nil?
        self.rest_arg = args
      when BlockArgument
        raise "Multiple block args" unless block_arg.nil?
        self.block_arg = args
      else
        raise "Unknown argument type #{args.class}"
      end
    end

    def args
      args = (required || []) + (opt_args || [])
      args << block_arg if block_arg
      return args
    end
  end

  class Argument < Node
    include Typed

    def resolved!(typer)
      typer.learn_local_type(typer.containing_scope(self), name, @inferred_type)
      super
    end
  end

  class RequiredArgument < Argument
    include Named
    child :type_node

    def initialize(parent, line_number, name, type=nil, &block)
      super(parent, line_number, [type], &block)

      self.name = name
    end

    def infer(typer, expression)
      resolve_if(typer) do
        typer.get_scope(self) << name
        # if not already typed, check parent of parent (MethodDefinition)
        # for signature info
        method_def = parent.parent
        signature = method_def.signature

        if type_node
          if ::String === type_node  # How does this happen?
            signature[name.intern] = typer.type_reference(scope, type_node)
          else
            signature[name.intern] = type_node.type_reference(typer)
          end
        end

        # if signature, search for this argument
        signature[name.intern] || typer.local_type(typer.containing_scope(self), name)
      end
    end

    def validate_type_node
      if UnquotedValue === type_node
        self.type_node = type_node.type
      end
    end
  end

  class OptionalArgument < Argument
    include Named
    child :type_node
    child :value

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      self.name = name
    end

    def infer(typer, expression)
      resolve_if(typer) do
        typer.get_scope(self) << name
        # if not already typed, check parent of parent (MethodDefinition)
        # for signature info
        method_def = parent.parent
        signature = method_def.signature
        value_type = value.infer(typer, true)
        declared_type = type_node.type_reference(typer) if type_node
        signature[name.intern] = declared_type || value_type
      end
    end
  end

  class RestArgument < Argument
    include Named

    def initialize(parent, line_number, name)
      super(parent, line_number)

      self.name = name
    end

    def infer(typer, expression)
      typer.get_scope(self) << name
      super
    end
  end

  class BlockArgument < Argument
    include Named

    attr_accessor :optional
    alias optional? optional

    def initialize(parent, line_number, name)
      super(parent, line_number)

      self.name = name
    end

    def infer(typer, expression)
      typer.get_scope(self) << name
      super
    end
  end

  class MethodDefinition < Node
    include Annotated
    include Named
    include ClassScoped
    include Java::DubyLangCompiler.MethodDefinition

    child :signature
    child :arguments
    child :body
    # TODO change return_type to a child if we remove the 'returns' macro.
    attr_accessor :return_type, :exceptions

    attr_accessor :defining_class
    attr_accessor :visibility
    attr_accessor :abstract

    def initialize(parent, line_number, name, annotations=[], &block)
      @annotations = annotations
      super(parent, line_number, &block)
      self.name = name
      @visibility = (class_scope && class_scope.current_access_level) || :public
    end

    def name
      super
    end

    def infer(typer, expression)
      resolve_if(typer) do
        static_scope = typer.add_scope(self)
        @defining_class ||= begin
          static_scope.self_node = :self
          scope = typer.get_scope(self)
          @static = scope.self_type.meta?
          static_scope.self_type = if static?
            scope.self_type.meta
          else
            scope.self_type
          end
        end
        @annotations.each {|a| a.infer(typer, true)} if @annotations
        typer.infer(arguments, true)
        if @return_type
          if @return_type.kind_of?(UnquotedValue)
            @return_type = @return_type.node
            @return_type.parent = self
          else
            @return_type.parent = self
          end
          signature[:return] = @return_type.type_reference(typer)
        end
        
        if @exceptions
          signature[:throws] = @exceptions.map {|e| e.type_reference(typer)}
        end
        typer.infer_signature(self)
        forced_type = signature[:return]
        body_is_expression = (forced_type != typer.no_type)
        inferred_type = body ? typer.infer(body, body_is_expression) : typer.no_type

        if inferred_type && arguments.inferred_type.all?
          actual_type = if forced_type
            forced_type
          else
            inferred_type
          end
          
          if actual_type.kind_of? Mirah::AST::InlineCode
            raise Mirah::Typer::InferenceError.new("Method %s has the same signature as macro of the same name." % name,self) 
          end

          if actual_type.unreachable?
            actual_type = typer.no_type
          end

          if !abstract? &&
              forced_type != typer.no_type &&
              !actual_type.is_parent(inferred_type)
            raise Mirah::Typer::InferenceError.new(
                "Inferred return type %s is incompatible with declared %s" %
                [inferred_type, actual_type], self)
          end

          signature[:return] = actual_type
        end
      end
    end

    def resolve_if(typer)
      super(typer) do
        actual_type = type = yield
        argument_types = arguments.inferred_type
        # If we know the return type go ahead and tell the typer
        # even if we can't infer the body yet.
        type ||= signature[:return] if argument_types && argument_types.all?
        if type
          argument_types ||= [Mirah::AST.error_type] if type.error?
          typer.learn_method_type(defining_class, name, argument_types, type, signature[:throws])

          # learn the other overloads as well
          args_for_opt = []
          if arguments.args
            arguments.args.each do |arg|
              if OptionalArgument === arg
                arg_types_for_opt = args_for_opt.map do |arg_for_opt|
                  arg_for_opt.infer(typer, true)
                end
                typer.learn_method_type(defining_class, name, arg_types_for_opt, type, signature[:throws])
              end
              args_for_opt << arg
            end
          end
        end
        actual_type
      end
    end

    def abstract?
      @abstract || InterfaceDeclaration === class_scope
    end

    def static?
      @static
    end
  end

  class StaticMethodDefinition < MethodDefinition
    def static?
      true
    end
  end

  class ConstructorDefinition < MethodDefinition
    attr_accessor :delegate_args, :calls_super

    def initialize(*args)
      super
      extract_delegate_constructor
    end

    def validate_children
      super
      if @delegate_args
        @delegate_args.each {|arg| arg.parent = self}
      end
    end

    def first_node
      if body.kind_of? Body
        body.children[0]
      else
        body
      end
    end

    def first_node=(new_node)
      if body.kind_of? Body
        new_node.parent = body
        body.children[0] = new_node
      else
        self.body = new_node
      end
    end

    def extract_delegate_constructor
      # TODO verify that this constructor exists during type inference.
      possible_delegate = first_node
      if FunctionalCall === possible_delegate &&
          possible_delegate.name == 'initialize'
        @delegate_args = possible_delegate.parameters
      elsif Super === possible_delegate
        @calls_super = true
        @delegate_args = possible_delegate.parameters
        unless @delegate_args
          args = arguments.children.map {|x| x || []}
          @delegate_args = args.flatten.map do |arg|
            Local.new(self, possible_delegate.position, arg.name)
          end
        end
      end
      self.first_node = Noop.new(self, position) if @delegate_args
    end

    def infer(typer, expression)
      unless @inferred_type
        delegate_args.each {|a| typer.infer(a, true)} if delegate_args
      end
      super
    end
  end

  defmacro('returns') do |transformer, fcall, parent|
    mdef = fcall.parent
    mdef = mdef.parent until MethodDefinition === mdef
    mdef.return_type = fcall.parameters[0]
    Noop.new(parent, fcall.position)
  end


  defmacro('throws') do |transformer, fcall, parent|
    mdef = fcall.parent
    mdef = mdef.parent until MethodDefinition === mdef
    mdef.exceptions = fcall.parameters
    Noop.new(parent, fcall.position)
  end
end
