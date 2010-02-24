require 'duby/jvm/types'

module Duby
  class JVM::Types::Type
    def to_source
      "#{name}#{'[]' if array?}"
    end
  end

  module JavaSource
    JVMTypes ||= Duby::JVM::Types

    class Builder
      attr_accessor :package, :classes, :filename, :compiler
      
      def initialize(filename, compiler)
        @filename = filename
        @classes = []
        @compiler = compiler
      end
      
      def public_class(name, superclass=nil, *interfaces)
        cls = ClassBuilder.new(self, name, superclass, interfaces)
        @classes << cls
        cls
      end
      
      def public_interface(name, *interfaces)
        cls = InterfaceBuilder.new(self, name, interfaces)
        @classes << cls
        cls
      end
      
      def generate
        @classes.each do |cls|
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
          # TODO values
          puts "@#{annotation.name}"
        end
      end
    end
    
    class ClassBuilder
      include Helper
      include Duby::Compiler::JVM::JVMLogger
      attr_reader :package, :name, :superclass, :filename, :class_name, :out
      attr_reader :interfaces
      def initialize(builder, name, superclass, interfaces)
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
        @superclass = superclass || JVMTypes::Object
        @interfaces = interfaces
        @filename = "#{name}.java"
        @filename = "#{package.tr('.', '/')}/#{@filename}" if @package
        @out = Output.new
        @stopped = false
        @methods = []
        @fields = {}
        start
      end
      
      def compiler
        @builder.compiler
      end
      
      def start
        puts "// Generated from #{@builder.filename}"
        puts "package #{package};" if package
      end

      def finish_declaration
        return if @declaration_finished
        @declaration_finished = true
        print "public class #{class_name} extends #{superclass.name}"
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
        finish_declaration
        return if @stopped
        @methods.each do |method|
          @out << method.out
        end
        log "Class #{name} complete (#{@out.to_s.size})"
        @stopped = true
        dedent
        puts "}"
        log "Class #{name} complete (#{@out.to_s.size})"
      end
      
      def main
        public_static_method('main', [], JVMTypes::Void,
                             [JVMTypes::String.array_type, 'argv'])
      end
      
      def declare_field(name, type, static, annotations=[])
        finish_declaration
        return if @fields[name]
        static = static ? 'static' : ''
        annotate(annotations)
        puts "private #{static} #{type.to_source} #{name};"
        @fields[name] = true
      end
      
      def public_method(name, exceptions, type, *args)
        finish_declaration
        @methods << MethodBuilder.new(self,
                                      :name => name,
                                      :return => type,
                                      :args => args,
                                      :exceptions => exceptions)
        @methods[-1]
      end
      
      def public_static_method(name, exceptions, type, *args)
        finish_declaration
        @methods << MethodBuilder.new(self,
                                      :name => name,
                                      :return => type,
                                      :args => args,
                                      :static => true,
                                      :exceptions => exceptions)
        @methods[-1]
      end
      
      def public_constructor(exceptions, *args)
        finish_declaration
        @methods << MethodBuilder.new(self,
                                      :name => class_name,
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
        super(builder, name, nil, interfaces)
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
      
      def public_method(name, type, exceptions, *args)
        finish_declaration
        @methods << MethodBuilder.new(self,
                                      :name => name,
                                      :return => type,
                                      :args => args,
                                      :abstract => true,
                                      :exceptions => exceptions)
        @methods[-1]
      end
    end
    
    class MethodBuilder
      include Helper
      
      attr_accessor :name, :type, :out
      
      def initialize(cls, options)
        @class = cls
        @compiler = cls.compiler
        @out = Output.new
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
        @static = options[:static] && ' static'
        @abstract = options[:abstract] && ' abstract'
        @exceptions = options[:exceptions] || []
        @temps = 0
      end

      def start
        print "public#{@static}#{@abstract} #{@typename} #{@name}("
        @args.each_with_index do |(type, name), i|
          print ', ' unless i == 0
          print "#{type.to_source} #{name}"
        end
        print ')'
        unless @exceptions.empty?
          print ' throws '
          @exceptions.each_with_index do |exception, i|
            print ', ' unless i == 0
            print exception.name
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

      def declare_local(type, name)
        unless @locals[name]
          print "#{type.to_source} #{name} = "
          if block_given?
            yield self
          else
            print init_value(type)
          end
          puts ';'
          @locals[name] = type
        end
        name
      end
      
      def local?(name)
        !!@locals[name]
      end

      def tmp(type)
        @temps += 1
        declare_local(type, "temp$#{@temps}")
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