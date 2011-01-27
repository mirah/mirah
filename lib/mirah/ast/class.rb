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
  class ClassDefinition < Node
    include Annotated
    include Named
    include Scope
    include Java::DubyLangCompiler.ClassDefinition

    attr_accessor :interfaces
    attr_accessor :current_access_level
    attr_accessor :abstract

    child :superclass_node
    child :body

    attr_accessor :superclass

    def initialize(parent, position, name, annotations=[], &block)
      @abstract = false
      @annotations = annotations
      @interfaces = []
      @interface_nodes = []
      self.name = name
      self.parent = parent
      if Mirah::AST.type_factory.respond_to? :define_type
        Mirah::AST.type_factory.define_type(self)
      end
      # We need somewhere to collect nodes that get appended during
      # the transform phase.
      @extra_body = Body.new(self, position)
      super(parent, position, &block)
      if body
        @extra_body.insert(0, body)
      end
      self.body = @extra_body
    end

    def append_node(node)
      @extra_body << node
      node
    end

    def define_inner_class(position, name, &block)
      name = "#{self.name}$#{name}"
      append_node ClassDefinition.new(nil, position, name, &block)
    end

    def define_method(position, name, type, *args)
      append_node(_define_method(MethodDefinition, position, name, type, args))
    end

    def define_static_method(position, name, type, *args)
      append_node(
          _define_method(StaticMethodDefinition, position, name, type, args))
    end

    def define_constructor(position, *args, &block)
      append_node(_define_method(
          ConstructorDefinition, position, 'initialize', nil, args, &block))
    end

    def _define_method(klass, position, name, type, args)
      klass.new(nil, position, name) do |method|
        signature = {:return => type}
        if Arguments === args[0]
          args_node = args[0]
          args_node.parent = method
        else
          args_node = Arguments.new(method, position) do |args_node|
            arg_list = args.map do |arg_name, arg_type, arg_position|
              signature[arg_name.intern] = arg_type
              arg_position ||= position
              RequiredArgument.new(args_node, arg_position, arg_name)
            end
            [arg_list, nil, nil, nil]
          end
        end
        [
          signature,
          args_node,
          if block_given?
            yield(method)
          end
        ]
      end
    end

    def declare_field(position, name, type)
      field = FieldDeclaration.new(nil, position || self.position, name)
      field.type = type.dup
      append_node(field)
    end

    def infer(typer, expression)
      resolve_if(typer) do
        @superclass = superclass_node.type_reference(typer) if superclass_node
        @annotations.each {|a| a.infer(typer, true)} if @annotations
        @interfaces.concat(@interface_nodes.map{|n| n.type_reference(typer)})
        typer.define_type(self, name, superclass, @interfaces) do
          static_scope.self_type = typer.self_type
          typer.infer(body, false) if body
        end
      end
    end

    def implements(*types)
      raise ArgumentError if types.any? {|x| x.nil?}
      types.each do |type|
        if Mirah::AST::TypeReference === type
          @interfaces << type
        else
          @interface_nodes << type
        end
      end
    end
  end

  defmacro('implements') do |transformer, fcall, parent|
    klass = parent
    klass = klass.parent unless ClassDefinition === klass

    interfaces = fcall.parameters.map do |interface|
      interface.parent = klass
      interface
    end
    klass.implements(*interfaces)
    Noop.new(parent, fcall.position)
  end

  class InterfaceDeclaration < ClassDefinition
    attr_accessor :superclass, :interfaces
    child :interface_nodes
    child :body

    def initialize(parent, position, name, annotations)
      super(parent, position, name, annotations) {|p| }
      @abstract = true
      self.name = name
      @children = [[], nil]
      @children = yield(self)
    end

    def infer(typer, expression)
      resolve_if(typer) do
        @interfaces = interface_nodes.map {|i| i.type_reference(typer)}
        super
      end
    end

    def superclass_node
      nil
    end
  end

  class ClosureDefinition < ClassDefinition
    attr_accessor :enclosing_type
    def initialize(parent, position, name, enclosing_type)
      super(parent, position, name, []) do
        [nil, nil]
      end
      @enclosing_type = enclosing_type
    end
  end

  defmacro('interface') do |transformer, fcall, parent|
    raise Mirah::SyntaxError.new("Interface name required", fcall) unless fcall.parameters.size > 0
    interfaces = fcall.parameters
    interface_name = interfaces.shift
    if (Call === interface_name &&
        interface_name.parameters.size == 1)
      interfaces.unshift(interface_name.parameters[0])
      interface_name = interface_name.target
    end
    raise 'Interface body required' unless fcall.block
    InterfaceDeclaration.new(parent, fcall.position,
                             interface_name.name,
                             transformer.annotations) do |interface|
      interfaces.each {|x| x.parent = interface}
      [interfaces,
       if fcall.block.body
         fcall.block.body.parent = interface
         fcall.block.body
       end
      ]
    end
  end

  class FieldDeclaration < Node
    include Annotated
    include Named
    include ClassScoped
    include Typed

    child :type_node
    attr_accessor :type
    attr_accessor :static

    def initialize(parent, position, name, annotations=[], static = false, &block)
      @annotations = annotations
      super(parent, position, &block)
      self.name = name
      @static = static
    end

    def infer(typer, expression)
      resolve_if(typer) do
        @annotations.each {|a| a.infer(typer, true)} if @annotations
        @type = type_node.type_reference(typer)
      end
    end

    def resolved!(typer)
      if static
        typer.learn_static_field_type(class_scope, name, @inferred_type)
      else
        typer.learn_field_type(class_scope, name, @inferred_type)
      end
      super
    end
  end

  class FieldAssignment < Node
    include Annotated
    include Named
    include Valued
    include ClassScoped

    child :value
    attr_accessor :static

    def initialize(parent, position, name, annotations=[], static = false, &block)
      @annotations = annotations
      super(parent, position, &block)
      self.name = name
      @static = static
    end

    def infer(typer, expression)
      resolve_if(typer) do
        @annotations.each {|a| a.infer(typer, true)} if @annotations
        if static
          typer.learn_static_field_type(class_scope, name, typer.infer(value, true))
        else
          typer.learn_field_type(class_scope, name, typer.infer(value, true))
        end
      end
    end
  end

  class Field < Node
    include Annotated
    include Named
    include ClassScoped
    
    attr_accessor :static

    def initialize(parent, position, name, annotations=[], static = false, &block)
      @annotations = annotations
      super(parent, position, &block)
      self.name = name
      @static = static
    end

    def infer(typer, expression)
      resolve_if(typer) do
        @annotations.each {|a| a.infer(typer, true)} if @annotations
        if static
          typer.static_field_type(class_scope, name)
        else
          typer.field_type(class_scope, name)
        end
      end
    end
  end

  class AccessLevel < Node
    include ClassScoped
    include Named

    def initialize(parent, line_number, name)
      super(parent, line_number)
      self.name = name
      class_scope.current_access_level = name.to_sym
    end

    def infer(typer, expression)
      typer.no_type
    end
  end

  class Include < Node
    include Scoped

    def infer(typer, expression)
      children.each do |type|
        typeref = type.type_reference(typer)
        the_scope = scope.static_scope
        the_scope.self_type = the_scope.self_type.include(typeref)
      end
    end

    def compile(compiler, expression); end
  end

  defmacro("include") do |transformer, fcall, parent|
    raise "Included Class name required" unless fcall.parameters.size > 0
    Include.new(parent, fcall.position) do |include_node|
      fcall.parameters.map do |constant|
        constant.parent = include_node
        constant
      end
    end
  end
end
