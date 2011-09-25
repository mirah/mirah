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

require 'fileutils'

module Mirah::AST

  class Unquote < Node
    child :value

    def infer(typer, expression)
      raise Mirah::SyntaxError.new("Unquote used outside of macro", self)
    end

    def _dump(depth)
      vals = Unquote.__extracted
      index = vals.size
      vals << value
      Marshal.dump([position, index])
    end


    def self._load(str)
      if str =~ /^\d+$/
        # This just returns the exact node passed in.
        index = str.to_i
        Unquote.__injected[index].dup
      else
        position, index = Marshal.load(str)
        holder = UnquotedValue.new(nil, position)
        value = Unquote.__injected[index]
        begin
          holder << value.dup
        rescue TypeError
          holder << value
        end
        holder
      end
    end

    def self.__extracted
      Thread.current[:'Mirah::AST::Unqote.extracted']
    end

    def self.__extracted=(value)
      Thread.current[:'Mirah::AST::Unqote.extracted'] = value
    end

    def self.__injected
      Thread.current[:'Mirah::AST::Unqote.injected']
    end

    def self.__injected=(value)
      Thread.current[:'Mirah::AST::Unqote.injected'] = value
    end

    def self.extract_values
      values = []
      saved, self.__extracted = self.__extracted, values
      begin
        yield
        return values
      ensure
        self.__extracted = saved
      end
    end

    def self.inject_values(values)
      saved, self.__injected = self.__injected, values
      begin
        yield
      ensure
        self.__injected = saved
      end
    end
  end

  class UnquotedValue < Node
    java_import 'java.lang.Character'
    child :value

    def name
      case value
      when Mirah::AST::String
        value.literal
      when ::String
        value
      when Named
        value.name
      when Node
        value.string_value
      else
        raise "Bad unquote value for name #{value} (#{value.class})"
      end
    end

    def type
      Constant.new(nil, position, name)
    end

    def node
      case value
      when Node
        value
      when ::String
        c = value[0]
        if c == ?@
          return Field.new(nil, position, value[1, value.length])
        elsif Character.isUpperCase(c)
          return Constant.new(nil, position, value)
        else
          return Local.new(nil, position, value)
        end
      when ::Fixnum
        return Fixnum.new(nil, position, value)
      else
        raise "Bad unquote value for node #{value} (#{value.class})"
      end
    end

    def nodes
      case value
      when ::Array, Java::JavaUtil::List
        # TODO convert items to nodes.
        value.to_a
      else
        [node]
      end
    end

    def f_arg_item(value)
      case value
      when Arguments, Argument
        value
      when Node
        RequiredArgument.new(nil, position, value.string_value)
      when ::String
        RequiredArgument.new(nil, position, value)
      when ::Array, java.util.List
        name, type = value.map do |item|
          if item.kind_of?(Node)
            item.string_value
          else
            item.to_s
          end
        end
        RequiredArgument.new(nil, position, name, type)
      else
        raise "Bad unquote value for arg #{value} (#{value.class})"
      end
    end

    def f_arg
      case value
      when ::Array, java.util.List
        value.map {|item| f_arg_item(item)}
      else
        f_arg_item(value)
      end
    end
  end

  class UnquoteAssign < Node
    child :name
    child :value

    def infer(typer, expression)
      raise Mirah::SyntaxError.new("UnquoteAssign used outside of macro")
    end

    def _dump(depth)
      vals = Unquote.__extracted
      index = vals.size
      vals << self.name
      Marshal.dump([position, index, self.value])
    end


    def self._load(str)
      position, index, value = Marshal.load(str)
      holder = UnquotedValueAssign.new(nil, position)
      holder << Unquote.__injected[index].dup
      holder << value
      holder
    end
  end

  class UnquotedValueAssign < UnquotedValue
    child :name_node
    child :value

    def name
      raise "Bad unquote value #{value}"
    end

    def node
      if ScopedBody === self.name_node
        scope = name_node
        name_node = scope.children[0]
      else
        name_node = self.name_node
      end
      
      klass = LocalAssignment
      name = case name_node
        when Field
        # TODO support AttrAssign
          klass = FieldAssignment
          name_node.name
        when Named
          name_node.name
        when String
          name_node.literal
        else
          raise "Bad unquote value"
        end
        
      if name[0] == ?@
        name = name[1, name.length]
        klass = FieldAssignment
      end
      
      n = klass.new(nil, position, name)
      n << value
      n.validate_children
      
      if scope
        scope.children.clear
        scope << n
      else
        return n
      end
    end

    def f_arg
      raise "Bad unquote value"
    end
  end

  class MacroDefinition < Node
    include Named
    include Scoped

    child :arguments
    child :body

    attr_accessor :proxy

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      self.name = name
    end

    def infer(typer, expression)
      resolve_if(typer) do
        self_type = scope.static_scope.self_type
        extension_name = "%s$%s" % [self_type.name,
                                    typer.transformer.tmp("Extension%s")]
        klass = build_and_load_extension(self_type,
                                         extension_name,
                                         typer.transformer.state)

        # restore the self type since we're sharing a type factory
        typer.known_types['self'] = self_type

        arg_types = argument_types
        macro = self_type.add_compiled_macro(klass, name, arg_types)
        if arguments[-1].kind_of?(BlockArgument) && arguments[-1].optional?
          arg_types.pop
          self_type.add_method(name, arg_types, macro)
        end
        proxy.__inline__(Noop.new(parent, position))
        proxy.infer(typer, expression)
      end
    end

    def argument_types
      arguments.map do |arg|
        if arg.kind_of?(BlockArgument)
          TypeReference::BlockType
        else
          # TODO support typed args. Also there should be a way
          # to accept any AST node.
          Mirah::JVM::Types::Object
        end
      end
    end

    def signature
      args = argument_types
      if args.size > 0 && args[-1].block?
        args[-1] = BiteScript::ASM::Type.getObjectType('duby.lang.compiler.Block')
      end
      [nil] + args
    end

    def build_and_load_extension(parent, name, state)
      transformer = Mirah::Transform::Transformer.new(state)
      transformer.filename = name.gsub(".", "/")
      orig_factory = Mirah::AST.type_factory
      new_factory = orig_factory.dup
      Mirah::AST.type_factory = new_factory
      ast = build_ast(name, parent, transformer)
      classes = compile_ast(name, ast, transformer)
      loader = Mirah::Util::ClassLoader.new(
          JRuby.runtime.jruby_class_loader, classes)
      klass = loader.loadClass(name, true)
      if state.save_extensions
        annotate(parent, name)
      end
      Mirah::AST.type_factory = orig_factory
      klass
    end

    def annotate(type, class_name)
      node = type.unmeta.node
      if node
        extension = node.annotation('duby.anno.Extensions')
        extension ||= begin
          node.annotations << Annotation.new(
              nil, nil, BiteScript::ASM::Type.getObjectType('duby/anno/Extensions'))
          node.annotations[-1].runtime = false
          node.annotations[-1]
        end
        extension['macros'] ||= []
        macro = Annotation.new(nil, nil,
                               BiteScript::ASM::Type.getObjectType('duby/anno/Macro'))
        macro['name'] = name
        macro['signature'] = BiteScript::Signature.signature(*signature)
        macro['class'] = class_name
        extension['macros'] << macro
        # TODO deal with optional blocks.
      else
        puts "Warning: No ClassDefinition for #{type.name}. Macros can't be loaded from disk."
      end
    end

    def compile_ast(name, ast, transformer)
      begin
        # FIXME: This is JVM specific, and should move out of platform-independent code
        typer = Mirah::JVM::Typer.new(transformer)
        typer.infer(ast, false)
        typer.resolve(true)
        typer.errors.each do |e|
          raise e
        end
      ensure
        puts ast.inspect if transformer.state.verbose
      end
      # FIXME: This is JVM specific, and should move out of platform-independent code
      compiler = Mirah::JVM::Compiler::JVMBytecode.new
      ast.compile(compiler, false)
      class_map = {}
      compiler.generate do |outfile, builder|
        bytes = builder.generate
        name = builder.class_name.gsub(/\//, '.')
        class_map[name] = Mirah::Util::ClassLoader.binary_string bytes
        if transformer.state.save_extensions
          outfile = "#{transformer.destination}#{outfile}"
          FileUtils.mkdir_p(File.dirname(outfile))
          File.open(outfile, 'wb') do |f|
            f.write(bytes)
          end
        end
      end
      class_map
    end

    def build_ast(name, parent, transformer)
      # TODO should use a new type factory too.

      ast = Mirah::AST.parse_ruby("begin;end")
      ast = transformer.transform(ast, nil)

      # Start building the extension class
      extension = transformer.define_class(position, name)
      #extension.superclass = Mirah::AST.type(nil, 'duby.lang.compiler.Macro')
      extension.implements(Mirah::AST.type(nil, 'duby.lang.compiler.Macro'))

      extension.static_scope.import('duby.lang.compiler.Node', 'Node')
      extension.static_scope.package = scope.static_scope.package

      # The constructor just saves the state
      extension.define_constructor(
          position,
          ['mirah', Mirah::AST.type(nil, 'duby.lang.compiler.Compiler')],
          ['call', Mirah::AST.type(nil, 'duby.lang.compiler.Call')]) do |c|
        transformer.eval("@mirah = mirah;@call = call", '-', c, 'mirah', 'call')
      end

      node_type = Mirah::AST.type(nil, 'duby.lang.compiler.Node')

      # expand() parses the arguments out of call and then passes them off to
      # _expand
      expand = extension.define_method(
          position, 'expand', node_type)
      args = []
      arguments.each_with_index do |arg, i|
        # TODO optional args
        args << if arg.kind_of?(BlockArgument)
          "@call.block"
        else
          "Node(args.get(#{i}))"
        end
      end
      expand.body = transformer.eval(<<-end)
        args = @call.arguments
        _expand(#{args.join(', ')})
      end
      actual_args = arguments.map do |arg|
        type = if arg.kind_of?(BlockArgument)
          Mirah::AST.type(nil, 'duby.lang.compiler.Block')
        else
          node_type
        end
        [arg.name, type, arg.position]
      end
      m = extension.define_method(position, '_expand', node_type, *actual_args)
      scope.static_scope.imports.each do |short, long|
        m.static_scope.import(long, short)
      end
      scope.static_scope.search_packages.each do |package|
        m.static_scope.import(package, '*')
      end
      m.body = self.body
      ast.body = extension
      ast
    end
  end

  defmacro('defmacro') do |duby, fcall, parent|
    macro = fcall.parameters[0]
    block_arg = nil
    args = macro.parameters if macro.respond_to?(:parameters)
    body = if macro.respond_to?(:block) && macro.block
      macro.block
    else
      fcall.block
    end
    body = body.body if body

    MacroDefinition.new(parent, fcall.position, macro.name) do |mdef|
      # TODO optional args?
      args = if args
        args.map do |arg|
          case arg
          when LocalAssignment
            OptionalArgument.new(mdef, arg.position, arg.name) do |optarg|
              # TODO check that they actually passed nil as the value
              Null.new(parent, arg.value_node.position)
            end
          when FunctionalCall
            RequiredArgument.new(mdef, arg.position, arg.name)
          when BlockPass
            farg = BlockArgument.new(mdef, arg.position, arg.value.name)
            farg.optional = true if LocalAssignment === arg.value
            farg
          else
            raise "Unsupported argument #{arg}"
          end
        end
      else
        []
      end
      body.parent = mdef if body
      [args,  body]
    end
  end

  defmacro('macro') do |transformer, fcall, parent|
    # Alternate macro syntax.
    #   macro def foo(...);...;end
    # This one supports special names like []=,
    # but you can't use optional blocks.
    method = fcall.parameters[0]
    macro = MacroDefinition.new(parent, fcall.position, method.name)
    macro.arguments = method.arguments.args || []
    macro.body = method.body
    macro
  end

  defmacro('abstract') do |transformer, fcall, parent|
    class_or_method = fcall.parameters[0]
    class_or_method.abstract = true
    class_or_method
  end

  defmacro('puts') do |transformer, fcall, parent|
    Call.new(parent, fcall.position, "println") do |x|
      args = fcall.parameters
      args.each do |arg|
        arg.parent = x
      end
      [
        Call.new(x, fcall.position, "out") do |y|
          [
            Constant.new(y, fcall.position, "System"),
            []
          ]
        end,
        args,
        nil
      ]
    end
  end

  defmacro('print') do |transformer, fcall, parent|
    Call.new(parent, fcall.position, "print") do |x|
      args = fcall.parameters
      args.each do |arg|
        arg.parent = x
      end
      [
        Call.new(x, fcall.position, "out") do |y|
          [
            Constant.new(y, fcall.position, "System"),
            []
          ]
        end,
        args,
        nil
      ]
    end
  end

  class InlineCode
    def initialize(&block)
      @block = block
    end

    def inline(transformer, call)
      @block.call(transformer, call)
    end
  end
end
