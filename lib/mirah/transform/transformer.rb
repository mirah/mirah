module Mirah
  module Transform
    class Transformer
      begin
        include Java::DubyLangCompiler.Compiler
      rescue NameError
        $CLASSPATH << File.dirname(__FILE__) + '/../../../javalib/mirah-bootstrap.jar'
        include Java::DubyLangCompiler.Compiler
      end

      attr_reader :errors, :state
      attr_accessor :filename
      def initialize(state)
        @errors = []
        @tmp_count = 0
        @annotations = []
        @extra_body = nil
        @state = state
        @files = {""=>{:filename => "", :line => 0, :code => ""}}
      end

      def destination
        @state.destination
      end

      def verbose?
        @state.verbose
      end

      def annotations
        result, @annotations = @annotations, []
        return result
      end

      def add_annotation(annotation)
        @annotations << annotation
        Mirah::AST::Noop.new(annotation.parent, annotation.position)
      end

      def tmp(format="__xform_tmp_%d")
        format % [@tmp_count += 1]
      end

      class JMetaPosition
        attr_accessor :start_line, :end_line, :start_offset, :end_offset, :file
        attr_accessor :startpos, :endpos, :start_col, :end_col

        def initialize(transformer, startpos, endpos)
          @startpos = startpos
          @endpos = endpos
          @transformer = transformer
          @fileinfo = transformer.fileinfo(startpos.filename)
          puts "filename: #{startpos.filename.inspect}" unless @fileinfo
          @file = @fileinfo[:filename]
          @start_line = startpos.line
          @start_offset = startpos.pos
          @start_col = startpos.col
          @end_line = endpos.line
          @end_offset = endpos.pos
          @end_col = endpos.col
        end

        def +(other)
          JMetaPosition.new(@transformer, @startpos, other.endpos)
        end

        def start_line
          if @fileinfo
            @start_line + @fileinfo[:line]
          else
            @start_line
          end
        end

        def get_code
          code = @fileinfo[:code][@start_offset, @end_offset - @start_offset]
          filename = "#{@start_line}:#{@file}"
          [filename, code]
        end

        def underline
          result = ""
          @fileinfo[:code].each_with_index do |line, lineno|
            lineno += 1
            if lineno >= @start_line && lineno <= @end_line
              chomped = line.chomp
              result << chomped
              result << "\n"
              start = 0
              start = @start_col if lineno == @start_line
              result << " " * start
              endcol = chomped.size
              endcol = @end_col if lineno == @end_line
              result << "^" * [endcol - start, 1].max
              result << "\n"
              break if lineno == @end_line
            end
          end
          result
        end
      end

      def position(node)
        JMetaPosition.new(self, node.start_position, node.end_position)
      end

      def camelize(name)
        name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      end

      def transform(node, parent)
        return nil if node.nil?
        begin
          top = @extra_body.nil?
          if top
            @extra_body = Mirah::AST::Body.new(nil, position(node))
          end
          method = "transform_#{camelize(node[0])}"
          result = @helper.send method, node, parent
          if top
            body = result.body
            if body.kind_of?(Mirah::AST::Body) && @extra_body.empty?
              @extra_body = body
            else
              result.body = @extra_body
              body.parent = @extra_body
              @extra_body.children.insert(0, body)
            end
          end
          return result
        rescue Error => ex
          @errors << ex
          Mirah::AST::ErrorNode.new(parent, ex)
        rescue Exception => ex
          error = Mirah::InternalCompilerError.wrap(ex, nil)
          error.position = position(node)
          raise error
        end
      end

      def tag_filename(src, filename)
        key = "#{@files.size}$#{filename}"
        data = {:filename => filename, :line => 0, :code => src}
        if filename =~ /^(\d+)\$(.+)/
          data[:line] = $1.to_i
          data[:filename] = $2
        end
        @files[key] = data
        key
      end

      def untag_filename(filename)
        @files[filename][:filename]
      end

      def fileinfo(filename)
        @files[filename]
      end

      def eval(src, filename='-', parent=nil, *vars)
        node = Mirah::AST.parse_ruby(self, src, filename)
        duby_node = transform(node, nil).body
        duby_node.parent = parent
        duby_node
      end

      def dump_ast(node, call=nil)
        encoded = nil
        values = []
        node.each_descendant do |n|
          if Mirah::AST::Unquote === n || Mirah::AST::UnquoteAssign === n
            values << n.value
          end
        end
        filename, code = node.position.get_code
        encoded = "#{filename}$#{code}"
        scope = get_scope(call) if call
        result = Mirah::AST::Array.new(nil, node.position)
        if encoded.size < 65535
          result << Mirah::AST::String.new(result, node.position, encoded)
        else
          strings = Mirah::AST::StringConcat.new(result, node.position)
          result << strings
          while encoded.size >= 65535
            chunk = encoded[0, 65535]
            encoded[0, 65535] = ""
            strings << Mirah::AST::String.new(strings, node.position, chunk)
          end
          strings << Mirah::AST::String.new(strings, node.position, encoded)
        end
        values.each do |value|
          if scope
            value.scope = scope
          end
          result << value
        end
        return result
      end

      def load_ast(args)
        nodes = args.to_a
        encoded = nodes.shift
        filename, source = encoded.split('$', 2)
        if source
          saved = self.__unquote_values
          begin
            self.__unquote_values = nodes.reverse
            mmeta_ast = Mirah::AST.parse_ruby(self, source, filename)
            ast = transform(mmeta_ast, nil)
            process_errors(self.errors)
            result = ast[0]
            result.parent = nil
          ensure
            self.__unquote_values = saved
          end
        else
          Mirah::AST::Unquote.inject_values(nodes) do
            result = Marshal.load(Base64.decode64(encoded))
          end
        end
        if Mirah::AST::UnquotedValue === result
          result.node
        else
          result
        end
      end

      def __unquote_values
        Thread.current[:'Mirah::Transform::Transformer.unquote_values']
      end

      def __unquote_values=(value)
        Thread.current[:'Mirah::Transform::Transformer.unquote_values'] = value
      end

      def __ruby_eval(code, arg)
        self.instance_eval(code)
      end

      def fixnum(value)
        node = eval("1")
        node.literal = value
        node
      end

      def constant(name, array=false)
        node = eval("Foo")
        node.name = name
        node.array = array
        node
      end

      def cast(type, value)
        if value.kind_of?(String)
          value = Mirah::AST::Local.new(@extra_body, @extra_body.position, value)
        end
        fcall = eval("Foo()")
        fcall.name = type
        fcall.parameters = [value]
        fcall
      end

      def string(value)
        node = eval('"Foo"')
        node.literal = value
        node
      end

      def empty_array(type_node, size_node)
        node = eval('int[0]')
        node.type_node = type_node
        node.size = size_node
        node
      end

      def find_class(name)
        AST.type(nil, name, false, false)
      end

      def expand(fvcall, parent)
        result = yield self, fvcall, parent
        unless AST::Node === result
          raise Error.new('Invalid macro result', fvcall.position)
        end
        result
      end

      def append_node(node)
        @extra_body << node
        node
      end

      def define_class(position, name, &block)
        append_node Mirah::AST::ClassDefinition.new(@extra_body, position, name, &block)
      end

      def defineClass(name, superclass=nil, interfaces=nil)
        define_class(@extra_body.position, name) do |class_def|
          superclass = Mirah::AST::Constant.new(class_def, class_def.position, superclass)
          superclass.parent = class_def
          if interfaces
            class_def.implements(*interfaces.map {|i|  Mirah::AST::Constant.new(class_def, class_def.position, i)})
          end
          [superclass, body(class_def)]
        end
      end

      def body(parent=nil)
        parent ||= @extra_body
        Mirah::AST::Body.new(parent, parent.position)
      end

      def define_closure(position, name, enclosing_type)
        target = self
        parent = @extra_body
        enclosing_type = enclosing_type.unmeta
        if enclosing_type.respond_to?(:node) && enclosing_type.node
          parent = target = enclosing_type.node
        end
        target.append_node(Mirah::AST::ClosureDefinition.new(
            parent, position, name, enclosing_type))
      end
    end
  end
end