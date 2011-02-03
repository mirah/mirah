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
  class Body < Node
    include Java::DubyLangCompiler.Body

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    # Type of a block is the type of its final element
    def infer(typer, expression)
      unless @inferred_type
        @typer ||= typer
        @self_type ||= typer.self_type
        if children.size == 0
          @inferred_type = typer.no_type
        else
          last = children.size - 1
          children.each_with_index do |child, i|
            child_is_expression = (i == last && expression)
            @inferred_type = typer.infer(child, child_is_expression)
          end
        end

        if @inferred_type
          resolved!
        else
          typer.defer(self)
        end
      end

      @inferred_type
    end

    def string_value
      if children.size == 1
        children[0].string_value
      else
        super
      end
    end

    def <<(node)
      super
      if @typer
        orig_self = @typer.self_type
        @typer.known_types['self'] = @self_type
        @typer.infer(node, true)
        @typer.known_types['self'] = orig_self
      end
      self
    end

    def add_node(node)
      self << node
    end

  end

  # class << self
  class ClassAppendSelf < Body
    include Scope
    include Scoped

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer, expression)
      static_scope.self_type = scope.static_scope.self_type.meta
      super
    end
  end

  class ScopedBody < Body
    include Scope
    include Scoped

    def infer(typer, expression)
      static_scope.self_type ||= typer.self_type
      super
    end

    def binding_type(duby=nil)
      static_scope.binding_type(defining_class, duby)
    end

    def binding_type=(type)
      static_scope.binding_type = type
    end

    def has_binding?
      static_scope.has_binding?
    end

    def type_reference(typer)
      raise Mirah::SyntaxError.new("Invalid type", self) unless children.size == 1
      children[0].type_reference(typer)
    end

    def inspect_children(indent=0)
      indent_str = ' ' * indent
      str = ''
      if static_scope.self_node
        str << "\n#{indent_str}self: "
        if Node === static_scope.self_node
          str << "\n" << static_scope.self_node.inspect(indent + 1)
        else
          str << static_scope.self_node.inspect
        end
      end
      str << "\n#{indent_str}body:" << super(indent + 1)
    end
  end

  class Block < Node
    include Scoped
    include Scope
    include Java::DubyLangCompiler::Block
    child :args
    child :body

    def initialize(parent, position, &block)
      super(parent, position) do
        static_scope.parent = scope.static_scope
        yield(self) if block_given?
      end
    end

    def prepare(typer, method)
      duby = typer.transformer
      interface = method.argument_types[-1]
      outer_class = scope.defining_class
      binding = scope.binding_type(duby)
      name = "#{outer_class.name}$#{duby.tmp}"
      klass = duby.define_closure(position, name, outer_class)
      klass.interfaces = [interface]
      klass.define_constructor(position,
                               ['binding', binding]) do |c|
          duby.eval("@binding = binding", '-', c, 'binding')
      end

      # TODO We need a special scope here that allows access to the
      # outer class.
      static_scope.self_type = typer.infer(klass, true)

      add_methods(klass, binding, typer)

      call = parent
      instance = Call.new(call, position, 'new')
      instance.target = Constant.new(call, position, name)
      instance.parameters = [
        BindingReference.new(instance, position, binding)
      ]
      call.parameters << instance
      call.block = nil
      typer.infer(instance, true)
    end

    def add_methods(klass, binding, typer)
      found_def = false
      body.each do |node|
        if node.kind_of?(MethodDefinition)
          found_def = true
          node.static_scope = static_scope
          node.binding_type = binding
          klass.append_node(node)
        end
      end
      build_method(klass, binding, typer) unless found_def
    end

    def build_method(klass, binding, typer)
      # find all methods which would not otherwise be on java.lang.Object
      impl_methods = find_methods(klass.interfaces).select do |m|
        begin
          obj_m = java.lang.Object.java_class.java_method m.name, *m.parameter_types
        rescue NameError
          # not found on Object
          next true
        end
        # found on Object
        next false
      end

      raise "Multiple abstract methods found; cannot use block" if impl_methods.size > 1
      impl_methods.each do |method|
        mdef = klass.define_method(position,
                                   method.name,
                                   method.return_type,
                                   args.dup)
        mdef.static_scope = static_scope
        mdef.body = body.dup
        mdef.binding_type = binding
        typer.infer(mdef.body, true)
      end
    end

    def find_methods(interfaces)
      methods = []
      interfaces = interfaces.dup
      until interfaces.empty?
        interface = interfaces.pop
        methods += interface.declared_instance_methods.select {|m| m.abstract?}
        interfaces.concat(interface.interfaces)
      end
      methods
    end
  end

  class BindingReference < Node
    def initialize(parent, position, type)
      super(parent, position)
      @inferred_type = type
    end

    def infer(typer, expression)
      resolved! unless resolved?
      @inferred_type
    end
  end

  class Noop < Node
    def infer(typer, expression)
      resolved!
      @inferred_type ||= typer.no_type
    end
  end

  class Script < Node
    include Scope
    include Binding
    child :body

    attr_accessor :defining_class
    attr_reader :filename

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
      @package = ""
    end

    def infer(typer, expression)
      resolve_if(typer) do
        typer.set_filename(self, filename)
        @defining_class ||= begin
          static_scope.self_type = typer.self_type
        end
        typer.infer(body, false)
      end
    end

    def filename=(filename)
      @filename = filename
      if Script.explicit_packages
        static_scope.package = ''
      else
        package = File.dirname(@filename).tr('/', '.')
        package.sub! /^\.+/, ''
        static_scope.package = package
      end
    end

    class << self
      attr_accessor :explicit_packages
    end
  end
end
