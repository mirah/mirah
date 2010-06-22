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

      def _dump(depth)
        to_skip = %w(@parent @newline @inferred_type @resolved @proxy @scope @typer)
        vars = {}
        instance_variables.each do |name|
          next if to_skip.include?(name)
          vars[name] = instance_variable_get(name)
          begin
            Marshal.dump(vars[name]) if AST.verbose
          rescue
            puts "#{self}: Failed to marshal #{name}"
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
        node
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
          raise Duby::Typer::InferenceError.new(
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

      def containing_scope
        scope = self.scope.static_scope
        while scope.parent && scope.parent.include?(name)
          scope = scope.parent
        end
        scope
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

    class StaticScope
      attr_reader :parent
      attr_writer :self_type

      def initialize(parent=nil)
        @vars = {}
        @parent = parent
        @children = {}
      end

      def <<(name)
        @vars[name] = true
      end

      def include?(name, include_parent=true)
        @vars.include?(name) ||
            (include_parent && parent && parent.include?(name))
      end

      def captured?(name)
        if !include?(name, false)
          return false
        elsif parent && parent.include?(name)
          return true
        else
          return children.any? {|child| child.include?(name, false)}
        end
      end

      def children
        @children.keys
      end

      def add_child(scope)
        @children[scope] = true
      end

      def remove_child(scope)
        @children.delete(scope)
      end

      def parent=(parent)
        @parent.remove_child(self) if @parent
        parent.add_child(self)
        @parent = parent
      end

      def self_type
        if @self_type.nil? && parent
          @self_type = parent.self_type
        end
        @self_type
      end

      def binding_type(defining_class=nil, duby=nil)
        @binding_type ||= begin
          if parent
            parent.binding_type(defining_class, duby)
          else
            name = "#{defining_class.name}$#{duby.tmp}"
            factory = Duby::AST.type_factory
            if factory
              factory.declare_type(name)
            else
              Duby::AST::TypeReference.new(name, false, false)
            end
          end
        end
      end

      def binding_type=(type)
        if parent
          parent.binding_type = type
        else
          @binding_type = type
        end
      end

      def has_binding?
        @binding_type != nil || (parent && parent.has_binding?)
      end
    end

    module Scope
      attr_writer :static_scope
      def static_scope
        @static_scope ||= StaticScope.new
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
      attr_reader :values
      attr_accessor :runtime
      alias runtime? runtime

      def initialize(parent, position, klass)
        super(parent, position)
        @name = if klass.respond_to?(:class_name)
          klass.class_name
        else
          klass.name
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