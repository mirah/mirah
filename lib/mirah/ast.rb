require 'mirah/transform'
require 'mirah/ast/scope'

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

      def child_nodes
        java.util.ArrayList.new(@children)
      end

      def initialize(parent, position, children = [])
        JRuby.reference(self.class).setRubyClassAllocator(JRuby.reference(self.class).reified_class)
        unless parent.nil? || Duby::AST::Node === parent
          raise "Duby::AST::Node.new parent #{parent.class} must be nil or === Duby::AST::Node."
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
        to_skip = %w(@parent @newline @inferred_type @resolved @proxy @scope @class_scope @typer)
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

      def inspect(indent = 0)
        indent_str = ' ' * indent
        indent_str << to_s << inspect_children(indent)
      end

      def simple_name
        self.class.name.split("::")[-1]
      end

      def to_s; simple_name; end

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

    class Colon2 < Node; end

    class Constant < Node
      include Named
      include Scoped
      attr_accessor :array

      def initialize(parent, position, name)
        @name = name
        super(parent, position, [])
      end

      def infer(typer)
        @inferred_type ||= begin
          # TODO lookup constant, inline if we're supposed to.
          typer.type_reference(scope, name, @array, true)
        end
      end

      def type_reference(typer)
        typer.type_reference(scope, @name, @array)
      end
    end

    class Self < Node
      include Scoped
      def infer(typer)
        @inferred_type ||= scope.static_scope.self_type
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

      def infer(typer)
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
          value.children.map {|node| annotation_value(node, typer)}
        else
          # TODO Support other types
          ref = value.type_refence(typer)
          desc = BiteScript::Signature.class_id(ref)
          BiteScript::ASM::Type.getType(desc)
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
        @name = name
        @array = array
        @meta = meta
      end

      def type_reference(typer)
        typer.type_reference(nil, name, array, meta)
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
        AST.type(nil, name) if array?
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
      TypeReference::UnreachableType
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
