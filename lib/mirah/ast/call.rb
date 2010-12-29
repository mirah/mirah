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

require 'delegate'

module Mirah::AST
  class NodeProxy < DelegateClass(Node)
    include Java::DubyLangCompiler::Node
    def __inline__(node)
      node.parent = parent
      __setobj__(node)
    end

    def dup
      value = __getobj__.dup
      if value.respond_to?(:proxy=)
        new = super
        new.__setobj__(value)
        new.proxy = new
        new
      else
        value
      end
    end

    def _dump(depth)
      Marshal.dump(__getobj__)
    end

    def self._load(str)
      value = Marshal.load(str)
      if value.respond_to?(:proxy=)
        proxy = NodeProxy.new(value)
        proxy.proxy = proxy
      else
        value
      end
    end
  end

  class FunctionalCall < Node
    include Java::DubyLangCompiler.Call
    include Named
    include Scoped
    attr_accessor :cast, :inlined, :proxy
    alias cast? cast

    child :parameters
    child :block

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, &kids)
      @name = name
      @cast = false
    end

    def arguments
      @arguments ||= begin
        args = java.util.ArrayList.new(parameters.size)
        parameters.each do |param|
          args.add(param)
        end
        args
      end
    end

    def target
      nil
    end

    def validate_parameters
      parameters.each_with_index do |child, i|
        if UnquotedValue === child
          child.parent = self
          parameters[i] = child.node
        end
      end
    end

    def infer(typer)
      unless @inferred_type
        @self_type ||= scope.static_scope.self_type
        receiver_type = @self_type
        should_defer = false

        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        parameter_types << Mirah::AST.block_type if block

        unless should_defer
          if parameters.size == 1 && typer.known_type(scope, name)
            # cast operation
            resolved!
            self.cast = true
            @inferred_type = typer.known_type(scope, name)
          elsif parameters.size == 0 && scope.static_scope.include?(name)
            @inlined = Local.new(parent, position, name)
            proxy.__inline__(@inlined)
            return proxy.infer(typer)
          else
            @inferred_type = typer.method_type(receiver_type, name,
                                               parameter_types)
            if @inferred_type.kind_of? InlineCode
              @inlined = @inferred_type.inline(typer.transformer, self)
              proxy.__inline__(@inlined)
              return proxy.infer(typer)
            end
          end
        end

        if @inferred_type
          if block
            method = receiver_type.get_method(name, parameter_types)
            block.prepare(typer, method)
          end
          @inferred_type = receiver_type if @inferred_type.void?
          resolved!
        else
          if should_defer || receiver_type.nil?
            message = nil
          else
            parameter_names = parameter_types.map {|t| t.full_name}.join(', ')
            receiver = receiver_type.full_name
            desc = "#{name}(#{parameter_names})"
            kind = receiver_type.meta? ? "static" : "instance"
            message = "Cannot find #{kind} method #{desc} on #{receiver}"
          end
          typer.defer(proxy, message)
        end
      end

      @inferred_type
    end

    def type_reference(typer)
      typer.type_reference(scope, name)
    end
  end

  class Call < Node
    include Java::DubyLangCompiler.Call
    include Named
    include Scoped
    attr_accessor :cast, :inlined, :proxy
    alias cast? cast

    child :target
    child :parameters
    child :block

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, &kids)
      @name = name
    end

    def validate_parameters
      parameters.each_with_index do |child, i|
        if UnquotedValue === child
          child.parent = self
          parameters[i] = child.node
        end
      end
    end

    def arguments
      @arguments ||= begin
        args = java.util.ArrayList.new(parameters.size)
        parameters.each do |param|
          args.add(param)
        end
        args
      end
    end

    def infer(typer)
      unless @inferred_type
        receiver_type = typer.infer(target)
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        parameter_types << Mirah::AST.block_type if block

        unless should_defer
          @inferred_type = typer.method_type(receiver_type, name,
                                             parameter_types)
          if @inferred_type.kind_of? InlineCode
            @inlined = @inferred_type.inline(typer.transformer, self)
            proxy.__inline__(@inlined)
            return proxy.infer(typer)
          end
        end

        if @inferred_type
          if block && !receiver_type.error?
            method = receiver_type.get_method(name, parameter_types)
            block.prepare(typer, method)
          end
          @inferred_type = receiver_type if @inferred_type.void?
          resolved!
        else
          if should_defer
            message = nil
          else
            parameter_names = parameter_types.map {|t| t.full_name}.join(', ')
            receiver = receiver_type.full_name
            desc = "#{name}(#{parameter_names})"
            kind = receiver_type.meta? ? "static" : "instance"
            message = "Cannot find #{kind} method #{desc} on #{receiver}"
          end
          typer.defer(proxy, message)
        end
      end

      @inferred_type
    end

    def type_reference(typer)
      if name == "[]"
        # array type, top should be a constant; find the rest
        array = true
        elements = []
      else
        array = false
        elements = [name]
      end
      old_receiver = nil
      receiver = self.target
      while !receiver.eql?(old_receiver)
        old_receiver = receiver
        case receiver
        when Constant, FunctionalCall, Local, Annotation
          elements.unshift(receiver.name)
        when Call
          elements.unshift(receiver.name)
          receiver = receiver.target
        when String
          elements.unshift(receiver.literal)
        end
      end

      # join and load
      class_name = elements.join(".")
      begin
        typer.type_reference(scope, class_name, array)
      rescue NameError => ex
        typer.known_types[class_name] = Mirah::AST.error_type
        raise ex
      end
    end
  end

  class Super < Node
    include Named
    include Scoped
    attr_accessor :method, :cast
    alias :cast? :cast

    child :parameters

    def initialize(parent, line_number)
      super(parent, line_number)
      @call_parent = parent
      @call_parent = (@call_parent = @call_parent.parent) until MethodDefinition === @call_parent
      @cast = false
    end

    def name
      @call_parent.name
    end

    def infer(typer)
      @self_type ||= scope.static_scope.self_type.superclass

      unless @inferred_type
        receiver_type = @call_parent.defining_class.superclass
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        unless should_defer
          @inferred_type = typer.method_type(receiver_type, name,
                                             parameter_types)
        end

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end

  class BlockPass < Node
    child :value
  end
end