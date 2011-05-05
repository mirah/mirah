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
require 'mirah/transform'
require 'mirah/ast/scope'

module Mirah
  module AST
    class << self
      attr_accessor :verbose
    end

    # The top of the AST class hierarchy, this represents an abstract AST node.
    # It provides accessors for _children_, an array of all child nodes,
    # _parent_, a reference to this node's parent (nil if none), and _newline_,
    # whether this node represents a new line.
    class Node
      include Java::DubyLangCompiler.Node
      include Enumerable

      attr_accessor :children
      attr_accessor :parent
      attr_accessor :position
      attr_accessor :newline
      attr_accessor :inferred_type

      def self.child(name)
        @children ||= []
        index = @children.size
        class_eval <<-EOF
          def #{name}
            @children[#{index}]
          end

          def #{name}=(node)
            @children[#{index}] = _set_parent(node)
          end
        EOF
        @children << name
      end

      def self.child_name(i)
        @children[i] if @children
      end

      def child_nodes
        java.util.ArrayList.new(@children)
      end

      def initialize(parent, position, children = [])
        JRuby.reference(self.class).setRubyClassAllocator(JRuby.reference(self.class).reified_class)
        unless parent.nil? || Mirah::AST::Node === parent
          raise "Mirah::AST::Node.new parent #{parent.class} must be nil or === Mirah::AST::Node."
        end

        @parent = parent
        @newline = false
        @inferred_type = nil
        @resolved = false
        @position = position
        if block_given?
          @children ||= []
          @children = yield(self) || []
        else
          @children = children
        end
      end

      def _dump(depth)
        to_skip = %w(@parent @newline @inferred_type @resolved @proxy @scope @class_scope @static_scope @typer)
        vars = {}
        instance_variables.each do |name|
          next if to_skip.include?(name)
          vars[name] = instance_variable_get(name)
          begin
            Mirah::AST::Unquote.extract_values do
              Marshal.dump(vars[name]) if AST.verbose
            end
          rescue
            puts "#{self}: Failed to marshal #{name}"
            puts inspect
            puts $!, $@
            raise $!
          end
        end
          Marshal.dump(vars)
      end

      def self._load(vars)
        node = self.allocate
        Marshal.load(vars).each do |name, value|
          node.instance_variable_set(name, value)
        end
        node.children.each do |child|
          node._set_parent(child)
        end
        node.validate_children
        node
      end

      def validate_children
        validate_name if respond_to?(:validate_name)
        children.each_with_index do |child, i|
          validate_child(child, i)
        end
      end

      def validate_child(child, i)
        name = self.class.child_name(i)
        validator = :"validate_#{name}"
        if name && respond_to?(validator)
          send validator
        else
          if UnquotedValue === child
            self[i] = child.node
          end
        end
      end

      def line_number
        if @position
          @position.start_line + 1
        else
          0
        end
      end

      def log(message)
        puts "* [AST] [#{simple_name}] " + message if AST.verbose
      end

      def inspect_children(indent = 0)
        indent_str = ' ' * indent
        str = ''
        children.each_with_index do |child, i|
          extra_indent = 0
          if child
            name = self.class.child_name(i)
            if Mirah::AST.verbose && name
              str << "\n#{indent_str} #{name}:"
              extra_indent = 1
            end
            if ::Array === child
              child.each {|ary_child|
                if Mirah::AST.verbose && Node === ary_child && ary_child.parent != self
                   str << "\n#{indent_str} (wrong parent)"
                 end
                str << "\n#{ary_child.inspect(indent + extra_indent + 1)}"
              }
            elsif ::Hash === child || ::String === child
              str << "\n#{indent_str} #{child.inspect}"
            else
              if Mirah::AST.verbose && Node === child && child.parent != self
                str << "\n#{indent_str} (wrong parent)"
              end
              begin
                str << "\n#{child.inspect(indent + extra_indent + 1)}"
              rescue ArgumentError => ex
                str << "\n#{indent_str} #{child.inspect}"
              end
            end
          end
        end
        str
      end

      def inspect(indent = 0)
        indent_str = ' ' * indent
        indent_str << to_s << inspect_children(indent)
      end

      def simple_name
        self.class.name.split("::")[-1]
      end

      def to_s; simple_name; end

      def string_value
        raise Mirah::SyntaxError.new("Can't use #{self.class} as string literal")
      end

      def [](index) children[index] end

      def []=(index, node)
        node.parent = self
        @children[index] = node
      end

      def each(&b) children.each(&b) end

      def <<(node)
        @children << _set_parent(node)
        self
      end

      def insert(index, node)
        node.parent = self
        @children.insert(index, node)
      end

      def empty?
        @children.empty?
      end

      def resolved!(typer=nil)
        log "#{to_s} resolved!"
        @resolved = true
      end

      def resolved?; @resolved end

      def resolve_if(typer)
        unless resolved?
          @inferred_type = yield
          @inferred_type ? resolved!(typer) : typer.defer(self)
        end
        @inferred_type
      end

      def self.===(other)
        super || (other.kind_of?(NodeProxy) && (self === other.__getobj__))
      end

      def _set_parent(node)
        case node
        when Node
          node.parent = self
        when ::Array
          node.each {|x| x.parent = self if x}
        end
        node
      end

      def initialize_copy(other)
        # bug: node is deferred, but it's parent isn't
        #      parent gets duped
        #      duped parent is inferred so it's children aren't
        #      original node gets inferred, but not the duplicate child
        @inferred_type = @resolved = nil
        @parent = nil
        @children = []
        other.children.each do |child|
          case child
          when ::Array
            self << child.map {|x| x.dup}
          when nil
            self << nil
          else
            self << child.dup
          end
        end
      end

      def inferred_type!
        unless @inferred_type
          raise Mirah::InternalCompilerError.new(
              "Internal Error: #{self.class} never inferred", self)
        end
        inferred_type
      end
    end


    class ErrorNode < Node
      def initialize(parent, error)
        super(parent, error.position)
        @error = error
        @inferred_type = TypeReference::ErrorType
        @resolved = true
      end

      def infer(typer, expression)
      end
    end

    module Named
      attr_reader :name

      def name=(name)
        if Node === name
          name.parent = self
        end
        @name = name
      end

      def to_s
        "#{super}(#{name})"
      end

      def string_value
        name
      end

      def validate_name
        if UnquotedValue === @name
          @name = @name.name
        end
      end
    end

    module Typed
      attr_accessor :type
    end

    module Valued
      include Typed
      attr_accessor :value
    end

    module Literal
      include Typed
      attr_accessor :literal

      def to_s
        "#{super}(#{literal.inspect})"
      end

      def string_value
        literal.to_s
      end
    end

    module Annotated
      attr_accessor :annotations

      def annotation(name)
        name = name.to_s
        annotations.find {|a| a.name == name}
      end
    end

    module Binding
      def binding_type(duby=nil)
        static_scope.binding_type(defining_class, duby)
      end

      def binding_type=(type)
        static_scope.binding_type = type
      end

      def has_binding?
        static_scope.has_binding?
      end
    end

    class NodeProxy < DelegateClass(Node)
      include Java::DubyLangCompiler::Node
      include Java::DubyLangCompiler.Call
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

    class TypeReference < Node
      include Named
      attr_accessor :array
      alias array? array
      attr_accessor :meta
      alias meta? meta

      def initialize(name, array = false, meta = false, position=nil)
        super(nil, position)
        self.name = name
        @array = array
        @meta = meta
      end

      def type_reference(typer)
        typer.type_reference(nil, name, array, meta)
      end

      def to_s
        "Type(#{name}#{array? ? ' array' : ''}#{meta? ? ' meta' : ''})"
      end

      def full_name
        "#{name}#{array ? '[]' : ''}"
      end

      def ==(other)
        to_s == other.to_s
      end

      def eql?(other)
        self == other
      end

      def hash
        to_s.hash
      end

      def is_parent(other)
        # default behavior now is to disallow any polymorphic types
        self == other
      end

      def compatible?(other)
        # default behavior is only exact match right now
        self == other ||
            error? || other.error? ||
            unreachable? || other.unreachable?
      end

      def iterable?
        array?
      end

      def component_type
        AST.type(nil, name) if array?
      end

      def basic_type
        if array? || meta?
          TypeReference.new(name, false, false)
        else
          self
        end
      end

      def narrow(other)
        # only exact match allowed for now, so narrowing is a noop
        if error? || unreachable?
          other
        else
          self
        end
      end

      def unmeta
        TypeReference.new(name, array, false)
      end

      def meta
        TypeReference.new(name, array, true)
      end

      def void?
        name == :void
      end

      def error?
        name == :error
      end

      def null?
        name == :null
      end

      def unreachable?
        name == :unreachable
      end

      def block?
        name == :block
      end

      def primitive?
        true
      end

      def _dump(depth)
        Marshal.dump([name, array?, meta?])
      end

      def self._load(str)
        AST::Type(*Marshal.load(str))
      end

      NoType = TypeReference.new(:notype)
      NullType = TypeReference.new(:null)
      ErrorType = TypeReference.new(:error)
      UnreachableType = TypeReference.new(:unreachable)
      BlockType = TypeReference.new(:block)
    end

    class TypeDefinition < TypeReference
      attr_accessor :superclass, :interfaces

      def initialize(name, superclass, interfaces)
        super(name, false)

        @superclass = superclass
        @interfaces = interfaces
      end
    end

    def self.type_factory
      Thread.current[:ast_type_factory]
    end

    def self.type_factory=(factory)
      Thread.current[:ast_type_factory] = factory
    end

    # Shortcut method to construct type references
    def self.type(scope, typesym, array = false, meta = false)
      factory = type_factory
      if factory
        factory.type(scope, typesym, array, meta)
      else
        TypeReference.new(typesym, array, meta)
      end
    end

    def self.no_type
      factory = type_factory
      if factory
        factory.no_type
      else
        TypeReference::NoType
      end
    end

    def self.error_type
      TypeReference::ErrorType
    end

    def self.unreachable_type
      factory = type_factory
      if factory
        factory.unreachable_type
      else
        TypeReference::UnreachableType
      end
    end

    def self.block_type
      TypeReference::BlockType
    end

    def self.fixnum(parent, position, literal)
      Fixnum.new(parent, position, literal)
    end

    def self.float(parent, position, literal)
      Float.new(parent, position, literal)
    end

    def self.defmacro(name, &block)
      @macros ||= {}
      raise "Conflicting macros for #{name}" if @macros[name]
      @macros[name] = block
    end

    def self.macro(name)
      @macros[name]
    end
  end
end

require 'mirah/ast/local'
require 'mirah/ast/call'
require 'mirah/ast/flow'
require 'mirah/ast/literal'
require 'mirah/ast/method'
require 'mirah/ast/class'
require 'mirah/ast/structure'
require 'mirah/ast/type'
require 'mirah/ast/intrinsics'
