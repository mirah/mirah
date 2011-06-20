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
  AST = Java::MirahLangAst
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

      attr_accessor :inferred_type
      attr_accessor :scope

      def line_number
        if position
          position.start_line + 1
        else
          0
        end
      end

      def find_parent(*types)
        node = self
        node = node.parent until node.nil? || types.any? {|type| type === node}
        node
      end

      def log(message)
        puts "* [AST] [#{simple_name}] " + message if AST.verbose
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

      def inferred_type!
        unless @inferred_type
          raise Mirah::InternalCompilerError.new(
              "Internal Error: #{self.class} never inferred", self)
        end
        inferred_type
      end

      def inline(typer, new_node)
        parent.replaceChild(self, new_node)
        @inferred_type = AST.unreachable_type
        typer.infer(new_node, expression)
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
