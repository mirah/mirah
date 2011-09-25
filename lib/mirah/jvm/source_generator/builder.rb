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

require 'mirah/jvm/types'

module Mirah
  class JVM::Types::Type
    def to_source
      java_name = name
      java_name = java_name.tr('$', '.')
      "#{java_name}#{'[]' if array?}"
    end
  end

  module JavaSource
    JVMTypes ||= Mirah::JVM::Types

    class Builder
      attr_accessor :package, :classes, :filename, :compiler

      def initialize(filename, compiler)
        @filename = filename
        @classes = {}
        @compiler = compiler
      end

      def define_class(name, opts={})
        superclass = opts[:superclass]
        interfaces = opts[:interfaces]
        abstract = opts[:abstract]
        cls = ClassBuilder.new(self, name, superclass, interfaces, abstract)
        container = self
        if name.include? ?$
          path = name.split '$'
          name = path.pop
          path.each do |piece|
            container = container.classes[piece]
          end
        end
        container.classes[name] = cls
      end

      def public_interface(name, *interfaces)
        cls = InterfaceBuilder.new(self, name, interfaces)
        @classes[name] = cls
        cls
      end

      def generate
        @classes.values.each do |cls|
          yield cls.filename, cls
        end
      end
    end

    class Output
      def initialize
        @out = ""
        @indent = 0
      end

      def puts(*lines)
        lines.each do |line|
          print_indent
          @out << line.to_s
          @out << "\n"
          @indented = false
        end
      end

      def print_indent
        @indent ||= 0
        @out << (' ' * @indent) unless @indented
        @indented = true
      end

      def print(str)
        print_indent
        @out << str.to_s
      end

      def indent
        @indent += 2
      end

      def dedent
        @indent -= 2
      end

      def <<(other)
        other.to_s.each_line do |line|
          print_indent
          print(line)
          @indented = false
        end
      end

      def to_s
        @out
      end
    end

    module Helper
      def puts(*args)
        @out.puts(*args)
      end

      def print(*args)
        @out.print(*args)
      end

      def indent
        @out.indent
      end

      def dedent
        @out.dedent
      end

      def block(line='')
        puts line + " {"
        indent
        yield
        dedent
        puts "}"
      end

      def init_value(type)
        # TODO move this to types?
        case type
        when JVMTypes::Boolean
          'false'
        when JVMTypes::PrimitiveType, JVMTypes::NarrowingType
          '0'
        else
          'null'
        end
      end

      def annotate(annotations)
        annotations.each do |annotation|
          puts annotation_value(annotation)
        end
      end

      def annotation_value(value)
        case value
        when Java::JavaLang::Integer
          value.to_s
        when Java::JavaLang::String, String
          value.to_s.inspect
        when Array
          values = value.map{|x|annotation_value(x)}.join(", ")
          "{#{values}}"
        when BiteScript::ASM::Type
          value.getClassName.gsub("$", ".")
        when Mirah::AST::Annotation
          name = value.name.gsub("$", ".")
          values = value.values.map {|n, v| "#{n}=#{annotation_value(v)}"}
          "@#{name}(#{values.join ', '})"
        else
          raise "Unsupported annotation value #{value.inspect}"
        end
      end
    end

    class ClassBuilder
      include Helper
      include Mirah::JVM::Compiler::JVMBytecode::JVMLogger
      attr_reader :package, :name, :superclass, :filename, :class_name, :out
      attr_reader :interfaces, :abstract
      def initialize(builder, name, superclass, interfaces, abstract)
        @builder = builder
        @package = builder.package
        if @package
          @name = "#{@package}.#{name}"
        else
          @name = name
        end
        if name =~ %r{[/.]}
          pieces = name.split(%r{[/.]})
          name = pieces.pop
          @package = pieces.join('.')
        end
        @class_name = name
        if @class_name =~ /\$([^$]+)/
          @class_name = $1
          @static = true
          @inner_class = true
        end
        @superclass = superclass || JVMTypes::Object
        @interfaces = interfaces
        @filename = "#{name}.java"
        @filename = "#{package.tr('.', '/')}/#{@filename}" if @package
        @out = Output.new
        @stopped = false
        @methods = []
        @fields = {}
        @inner_classes = {}
        @abstract = abstract
        start
      end

      def compiler
        @builder.compiler
      end

      def classes
        @inner_classes
      end

      def start
        unless @inner_class
          puts "// Generated from #{@builder.filename}"
          puts "package #{package};" if package
        end
      end

      def finish_declaration
        return if @declaration_finished
        raise "Already stopped class #{class_name}" if @stopped

        @declaration_finished = true
        modifiers = "public#{' static' if @static}#{' abstract' if @abstract}"
        print "#{modifiers} class #{class_name} extends #{superclass.name}"
        unless @interfaces.empty?
          print " implements "
          @interfaces.each_with_index do |interface, index|
            print ', ' unless index == 0
            print interface.to_source
          end
        end
        puts " {"
        indent
      end

      def stop
        return if @stopped
        finish_declaration
        @methods.each do |method|
          @out << method.out
        end
        @inner_classes.values.each do |inner_class|
          @out << inner_class.out
        end
        log "Class #{name} complete (#{@out.to_s.size})"
        @stopped = true
        dedent
        puts "}"
        log "Class #{name} complete (#{@out.to_s.size})"
      end

      def main
        build_method('main', :public, :static, [], JVMTypes::Void,
                     [JVMTypes::String.array_type, 'argv'])
      end

      def declare_field(name, type, static, access='private', annotations=[])
        finish_declaration
        return if @fields[name]
        static = static ? ' static' : ''
        annotate(annotations)
        puts "#{access}#{static} #{type.to_source} #{name};"
        @fields[name] = true
      end

      def build_method(name, visibility, static, exceptions, type, *args)
        finish_declaration
        type ||= Mirah::AST::type(nil, :void)
        @methods << MethodBuilder.new(self,
                                      :name => name,
                                      :visibility => visibility,
                                      :static => static,
                                      :return => type,
                                      :args => args,
                                      :exceptions => exceptions)
        @methods[-1]
      end

      def build_constructor(visibility, exceptions, *args)
        finish_declaration
        @methods << MethodBuilder.new(self,
                                      :name => class_name,
                                      :visibility => visibility,
                                      :args => args,
                                      :exceptions => exceptions)
        @methods[-1]
      end

      def generate
        stop
        @out.to_s
      end
    end

    class InterfaceBuilder < ClassBuilder
      def initialize(builder, name, interfaces)
        super(builder, name, nil, interfaces, true)
      end

      def finish_declaration
        return if @declaration_finished
        @declaration_finished = true
        print "public interface #{class_name}"
        unless @interfaces.empty?
          print " extends "
          @interfaces.each_with_index do |interface, index|
            print ', ' unless index == 0
            print interface.to_source
          end
        end
        puts " {"
        indent
      end

      def build_method(name, visibility, static, exceptions, type, *args)
        raise "Interfaces can't have static methods" if static
        finish_declaration
        type ||= Mirah::AST::type(nil, :void)
        @methods << MethodBuilder.new(self,
                                      :name => name,
                                      :visibility => visibility,
                                      :return => type,
                                      :args => args,
                                      :abstract => true,
                                      :exceptions => exceptions)
        @methods[-1]
      end
    end

    class MethodBuilder
      include Helper

      attr_accessor :name, :type, :out, :klass

      def initialize(cls, options)
        @class = cls
        @klass = cls
        @compiler = cls.compiler
        @out = Output.new
        @visibility = options[:visibility]
        @name = options[:name]
        @type = options[:return]
        @typename = @type && @type.to_source
        @locals = {}
        @args = options[:args].map do |arg|
          unless arg.kind_of? Array
            arg = [arg.inferred_type, arg.name]
          end
          @locals[arg[1]] = arg[0]
          arg
        end
        @static = options[:static] ? ' static' : nil
        @abstract = options[:abstract] && ' abstract'
        @exceptions = options[:exceptions] || []
        @temps = 0
      end

      def start
        print "#{@visibility}#{@static}#{@abstract} #{@typename} #{@name}("
        @args.each_with_index do |(type, name), i|
          print ', ' unless i == 0
          print "#{type.to_source} #{name}"
        end
        print ')'
        unless @exceptions.empty?
          print ' throws '
          @exceptions.each_with_index do |exception, i|
            print ', ' unless i == 0
            print exception.to_source
          end
        end
        if @abstract
          puts ";"
          def self.puts(*args); end
          def self.print(*args); end
        else
          puts " {"
        end
        indent
      end

      def stop
        dedent
        puts "}"
      end

      def declare_local(type, name, initialize=true)
        unless @locals[name]
          if initialize
            print "#{type.to_source} #{name} = "
            if block_given?
              yield self
            else
              print init_value(type)
            end
            puts ';'
          end
          @locals[name] = type
        end
        name
      end

      def local?(name)
        !!@locals[name]
      end

      def tmp(type, &block)
        @temps += 1
        declare_local(type, "temp$#{@temps}", &block)
      end

      def label
        @temps += 1
        "label#{@temps}"
      end

      def push_int(value)
        print value
      end

      def ldc_float(value)
        print "(float)#{value}"
      end

      def ldc_double(value)
        print value
      end
      
      def ldc_long(value)
        print "#{value}L"
      end

      def ldc_class(type)
        print "#{type.to_source}.class"
      end

      def instanceof(type)
        print " instanceof #{type.to_source}"
      end

      def method_missing(name, *args)
        if name.to_s =~ /.const_(m)?(\d)/
          print '-' if $1
          print $2
        else
          super
        end
      end
    end
  end
end
