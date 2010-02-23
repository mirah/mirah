require 'duby/transform'

module Duby
  module AST
    class << self
      attr_accessor :verbose
    end

    # The top of the AST class hierarchy, this represents an abstract AST node.
    # It provides accessors for _children_, an array of all child nodes,
    # _parent_, a reference to this node's parent (nil if none), and _newline_,
    # whether this node represents a new line.
    class Node
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

      def initialize(parent, position, children = [])
        @parent = parent
        @newline = false
        @inferred_type = nil
        @resolved = false
        @position = position
        if block_given?
          @children = yield(self) || []
        else
          @children = children
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

      def inspect(indent = 0)
        indent_str = ' ' * indent
        str = indent_str + to_s
        children.each_with_index do |child, i|
          extra_indent = 0
          if child
            name = self.class.child_name(i)
            if Duby::AST.verbose && name
              str << "\n#{indent_str} #{name}:"
              extra_indent = 1
            end
            if ::Array === child
              child.each {|ary_child|
                if Duby::AST.verbose && Node === ary_child && ary_child.parent != self
                   str << "\n#{indent_str} (wrong parent)"
                 end
                str << "\n#{ary_child.inspect(indent + extra_indent + 1)}"
              }
            elsif ::Hash === child
              str << "\n#{indent_str} #{child.inspect}"
            else
              if Duby::AST.verbose && Node === child && child.parent != self
                str << "\n#{indent_str} (wrong parent)"
              end
              str << "\n#{child.inspect(indent + extra_indent + 1)}"
            end
          end
        end
        str
      end

      def simple_name
        self.class.name.split("::")[-1]
      end

      def to_s; simple_name; end

      def [](index) children[index] end

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

      def resolved!
        log "#{to_s} resolved!"
        @resolved = true
      end

      def resolved?; @resolved end

      def resolve_if(typer)
        unless resolved?
          @inferred_type = yield
          @inferred_type ? resolved! : typer.defer(self)
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
    end

    class ErrorNode < Node
      def initialize(parent, error)
        super(parent, error.position)
        @error = error
        @inferred_type = TypeReference::ErrorType
        @resolved = true
      end

      def infer(typer)
      end
    end

    module Named
      attr_accessor :name

      def to_s
        "#{super}(#{name})"
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
    end

    module Scoped
      def scope
        @scope ||= begin
          scope = parent
          raise "No parent for #{self.class.name} at #{line_number}" if scope.nil?
          until scope.class.include?(Scope)
            scope = scope.parent
          end
          scope
        end
      end
    end

    module ClassScoped
      def scope
        @scope ||= begin
          scope = parent
          scope = scope.parent until scope.nil? || ClassDefinition === scope
          scope
        end
      end
    end

    module Annotated
      attr_accessor :annotations

      def annotation(name)
        name = name.to_s
        annotations.find {|a| a.name == name}
      end
    end

    module Scope; end

    class Colon2 < Node; end

    class Constant < Node
      include Named
      def initialize(parent, position, name)
        @name = name
        super(parent, position, [])
      end

      def infer(typer)
        @inferred_type ||= begin
          typer.type_reference(name, false, true)
        end
      end
    end

    class Self < Node
      def infer(typer)
        @inferred_type ||= typer.self_type
      end
    end

    class VoidType < Node; end

    class Annotation < Node
      def initialize(parent, position, klass)
        super(parent, position)
        @class = klass
        @values = []
      end

      def name
        @class.name
      end

      def type
        @class
      end

      def []=(name, value)
        # TODO support annotation arguments
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
        @name = name
        @array = array
        @meta = meta
      end

      def to_s
        "Type(#{name}#{array? ? ' array' : ''}#{meta? ? ' meta' : ''})"
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
        AST.type(name) if array?
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
    def self.type(typesym, array = false, meta = false)
      factory = type_factory
      if factory
        factory.type(typesym, array, meta)
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
      TypeReference::UnreachableType
    end

    def self.block_type
      TypeReference::BlockType
    end

    def self.fixnum(parent, position, literal)
      factory = type_factory
      if factory
        factory.fixnum(parent, position, literal)
      else
        Fixnum.new(parent, position, literal)
      end
    end

    def self.float(parent, position, literal)
      factory = type_factory
      if factory
        factory.float(parent, position, literal)
      else
        Float.new(parent, position, literal)
      end
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

require 'duby/ast/local'
require 'duby/ast/call'
require 'duby/ast/flow'
require 'duby/ast/literal'
require 'duby/ast/method'
require 'duby/ast/class'
require 'duby/ast/structure'
require 'duby/ast/type'
require 'duby/ast/intrinsics'