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
      attr_accessor :children
      attr_accessor :parent
      attr_accessor :newline
      attr_accessor :inferred_type

      def initialize(parent, position, children = [])
        @parent = parent
        @children = children
        @newline = false
        @inferred_type = nil
        @resolved = false
        @position = position
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
        children.each do |child|
          if child
            if ::Array === child
              child.each {|ary_child|
                str << "\n#{ary_child.inspect(indent + 1)}"
              }
            elsif ::Hash === child
              str << "\n#{indent_str} #{child.inspect}"
            else
              str << "\n#{child.inspect(indent + 1)}"
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
    end
    
    class ErrorNode < Node
      def initialize(parent, error)
        super(parent, error.position.start_line + 1)
        @error = error
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
          scope = scope.parent until scope.class.include? Scope
          scope
        end
      end
    end

    module ClassScoped
      def scope
        @scope ||= begin
          scope = parent
          scope = scope.parent until ClassDefinition === scope
          scope
        end
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

    class Self < Node; end

    class VoidType < Node; end

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
        self == other
      end

      def narrow(other)
        # only exact match allowed for now, so narrowing is a noop
        self
      end

      def unmeta
        TypeReference.new(name, array, false)
      end

      def meta
        TypeReference.new(name, array, true)
      end

      NoType = TypeReference.new(:notype)
      NullType = TypeReference.new(:null)
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