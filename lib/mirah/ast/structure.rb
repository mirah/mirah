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

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer, expression)
      static_scope = typer.add_scope(self)
      static_scope.self_type = typer.get_scope(self).self_type.meta
      super
    end
  end

  class Block < Node
    include Java::DubyLangCompiler::Block
    child :args
    child :body

    def initialize(parent, position, &block)
      super(parent, position) do
        yield(self) if block_given?
      end
    end

    def prepare(typer, method)
      duby = typer.transformer
      interface = method.argument_types[-1]
      outer_class = find_parent(MethodDefinition, Script).defining_class
      name = "#{outer_class.name}$#{duby.tmp}"
      klass = duby.define_closure(position, name, outer_class)
      klass.interfaces = [interface]

      binding = typer.get_scope(self).binding_type(outer_class, duby)

      klass.define_constructor(position,
                               ['binding', binding]) do |c|
          duby.eval("@binding = binding", '-', c, 'binding')
      end

      add_methods(klass, binding, typer, typer.get_scope(self))

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

    def add_methods(klass, binding, typer, parent_scope)
      found_def = false
      body.each do |node|
        if node.kind_of?(MethodDefinition)
          found_def = true
          typer.add_scope(node).parent = parent_scope
          klass.append_node(node)
        end
      end
      build_method(klass, binding, typer, parent_scope) unless found_def
    end

    def build_method(klass, binding, typer, parent_scope)
      # find all methods which would not otherwise be on java.lang.Object
      impl_methods = find_methods(klass.interfaces).select do |m|
        begin
          # Very cumbersome. Not sure how it got this way.
          mirror = BiteScript::ASM::ClassMirror.for_name('java.lang.Object')
          mtype = Mirah::JVM::Types::Type.new(mirror)
          mtype.java_method m.name, *m.argument_types
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
        typer.add_scope(mdef).parent = parent_scope
        mdef.body = body.dup
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
    child :body

    attr_accessor :defining_class
    attr_reader :filename
    attr_accessor :package

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
      @package = ""
    end

    def infer(typer, expression)
      resolve_if(typer) do
        static_scope = typer.get_scope(self)
        typer.set_filename(static_scope, filename)
        @defining_class ||= begin
          static_scope.self_type = typer.self_type
        end
        typer.infer(body, false)
      end
    end

    def filename=(filename)
      @filename = filename
      if !Script.explicit_packages
        package = File.dirname(@filename).tr('/', '.')
        @package = package.sub(/^\.+/, '')
      end
    end

    class << self
      attr_accessor :explicit_packages
    end
  end

  class Annotation < Node
    attr_reader :values
    attr_accessor :runtime
    alias runtime? runtime

    child :name_node

    def initialize(parent, position, name=nil, &block)
      super(parent, position, &block)
      if name
        @name = if name.respond_to?(:class_name)
          name.class_name
        else
          name.name
        end
      end
      @values = {}
    end

    def name
      @name
    end

    def type
      BiteScript::ASM::Type.getObjectType(@name.tr('.', '/'))
    end

    def []=(name, value)
      @values[name] = value
    end

    def [](name)
      @values[name]
    end

    def infer(typer, expression)
      @inferred ||= begin
        @name = name_node.type_reference(typer).name if name_node
        @values.each do |name, value|
          if Node === value
            @values[name] = annotation_value(value, typer)
          end
        end
        true
      end
    end

    def annotation_value(node, typer)
      case node
      when String
        java.lang.String.new(node.literal)
      when Array
        node.children.map {|node| annotation_value(node, typer)}
      else
        # TODO Support other types
        ref = value.type_refence(typer)
        desc = BiteScript::Signature.class_id(ref)
        BiteScript::ASM::Type.getType(desc)
      end
    end
  end
end
