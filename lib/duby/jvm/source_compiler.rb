require 'duby'
require 'duby/ast'
require 'duby/jvm/types'
require 'duby/jvm/compiler'
require 'duby/jvm/source_generator/builder'
require 'duby/jvm/source_generator/precompile'
require 'duby/jvm/source_generator/loops'

class String
  def compile(compiler, expression)
    compiler.method.print self if expression
  end
end

module Duby
  module Compiler
    class JavaSource
      JVMTypes = Duby::JVM::Types
      include Duby::Compiler::JVM::JVMLogger
      attr_accessor :filename, :method, :static, :class, :lvalue

      Operators = [
        '+', '-', '+@', '-@', '/', '%', '*', '<',
        '<=', '==', '!=', '>=', '>',
        '<<', '>>', '>>>', '|', '&', '^', '~'
      ]
      ArrayOps = [
        '[]', '[]=', 'length'
      ]
      
      ImplicitReturn = Struct.new(:value)

      def initialize(filename)
        @filename = File.basename(filename)
        @static = true
        parts = filename.split '/'
        classname = Duby::Compiler::JVM.classname_from_filename(filename)
        package = parts.join('.') unless parts.empty?

        @file = Duby::JavaSource::Builder.new(filename, self)
        #@file.package = package
        @type = AST::type(classname)
      end

      def toplevel_class
        @class = @type.define(@file)
      end

      def generate(&block)
        log "Generating source files..."
        @file.generate do |filename, builder|
          log "  #{builder.class_name}"
          if block_given?
            yield filename, builder
          else
            File.open(filename, 'w') {|f| f.write(builder.generate)}
          end
        end
        log "...done!"
      end

      def define_main(body)
        body = body[0] if body.children.size == 1
        if body.class != AST::ClassDefinition
          @class = @type.define(@file)
          with :method => @class.main do
            log "Starting main method"

            @method.start

            body.compile(self, false)

            @method.stop
          end
          @class.stop
        else
          body.compile(self, false)
        end

        log "Main method complete!"
      end

      def define_method(node)
        name, signature, args = node.name, node.signature, node.arguments.args
        args ||= []
        return_type = signature[:return]
        exceptions = signature[:throws] || []
        with :static => @static || node.static? do
          if @static
            method = @class.public_static_method(name.to_s, return_type, exceptions, *args)
          else
            method = @class.public_method(name.to_s, return_type, exceptions, *args)
          end

          with :method => method do
            log "Starting new method #{name}"
            @method.annotate(node.annotations)
            @method.start

            unless @method.type.nil? || @method.type.void?
              self.return(ImplicitReturn.new(node.body))
            else
              node.body.compile(self, false) if node.body
            end
        
            log "Method #{name} complete!"
            @method.stop
          end
        end
      end

      def constructor(node)
        args = node.arguments.args || []
        exceptions = node.signature[:throws] || []
        method = @class.public_constructor(exceptions, *args)
        with :method => method do
          @method.annotate(node.annotations)
          @method.start
          if node.delegate_args
            delegate = if node.calls_super
              "super"
            else
              "this"
            end
            method.print "#{delegate}("
            node.delegate_args.each_with_index do |arg, index|
              method.print ', ' unless index == 0
              raise "Invalid constructor argument #{arg}" unless arg.expr?(self)
              arg.compile(self, true)
            end
            method.puts ");"
          end
          
          node.body.compile(self, false) if node.body
          method.stop
        end
      end

      def return(node)
        if @method.type.nil? || @method.type.void?
          @method.puts 'return;'
          return
        end
        if node.value.expr?(self)
          @method.print 'return '
          node.value.compile(self, true)
          @method.puts ';'
        else
          store_value('return ', node.value)
        end
      end

      def _raise(node)
        if node.expr?(self)
          @method.print 'throw '
          node.compile(self, true)
          @method.puts ';'
        else
          store_value('throw ', node)
        end
      end
      
      def rescue(node, expression)
        @method.block 'try' do
          maybe_store(node.body, expression)
        end
        node.clauses.each do |clause|
          clause.types.each do |type|
            name = clause.name || 'tmp$ex'
            @method.block "catch (#{type.to_source} #{name})" do
              maybe_store(clause.body, expression)
            end
          end
        end
      end
      
      def ensure(node, expression)
        @method.block 'try' do
          maybe_store(node.body, expression)
        end
        @method.block 'finally' do
          node.clause.compile(self, false)
        end
      end

      def line(num)
      end
      
      def declare_local(name, type)
        @method.declare_local(type, name)
      end
      
      def declare_field(name, type, annotations)
        @class.declare_field(name, type, @static, annotations)
      end

      def local(name, type)
        @method.print name
      end
      
      def field(name, type, annotations)
        name = name[1..-1]
        declare_field(name, type, annotations)
        @method.print "#{this}.#{name}"
      end

      def this
        @static ? @class.class_name : 'this'
      end

      def local_assign(name, type, expression, value)
        value = value.precompile(self)
        if method.local?(name)
          @method.print @lvalue if expression
          @method.print "#{name} = "
          value.compile(self, true)
          @method.puts ';'
        else
          @method.declare_local(type, name) do
            value.compile(self, true)
          end
          if expression
            @method.puts "#{@lvalue}#{name};"
          end
        end
      end

      def field_declare(name, type, annotations)
        name = name[1..-1]
        declare_field(name, type, annotations)
      end
      
      def local_declare(name, type)
        declare_local(name, type)
      end
      
      def field_assign(name, type, expression, value, annotations)
        name = name[1..-1]
        declare_field(name, type, annotations)
        lvalue = "#{@lvalue if expression}#{this}.#{name} = "
        store_value(lvalue, value)
      end
      
      def store_value(lvalue, value)
        if value.is_a? String
          @method.puts "#{lvalue}#{value};"
        elsif value.expr?(self)
          @method.print lvalue
          value.compile(self, true)
          @method.puts ';'
        else
          with :lvalue => lvalue do
            value.compile(self, true)
          end
        end
      end
      
      def assign(name, value)
        store_value("#{name} = ", value)
        name
      end

      def maybe_store(value, expression)
        if expression
          store_value(@lvalue, value)
        else
          value.compile(self, false)
        end
      end

      def body(body, expression)
        # all except the last element in a body of code is treated as a statement
        i, last = 0, body.children.size - 1
        while i < last
          body.children[i].compile(self, false)
          i += 1
        end
        # last element is an expression only if the body is an expression
        maybe_store(body.children[last], expression) if last >= 0
      end
      
      def branch_expression(node)
        node.condition.compile(self, true)
        @method.print ' ? ('
        if node.body
          node.body.compile(self, true)
        else
          @method.print @method.init_value(node.inferred_type)
        end
        @method.print ') : ('
        if node.else
          node.else.compile(self, true)
        else
          @method.print @method.init_value(node.inferred_type)
        end
        @method.print ')'
      end
      
      def branch(node, expression)
        if expression && node.expr?(self)
          return branch_expression(node)
        end
        predicate = node.condition.predicate.precompile(self)
        @method.print 'if ('
        predicate.compile(self, true)
        @method.block ")" do
          if node.body
            maybe_store(node.body, expression)
          elsif expression
            store_value(@lvalue, @method.init_value(node.inferred_type))
          end
        end
        if node.else || expression
          @method.block 'else' do
            if node.else
              maybe_store(node.else, expression)
            else
              store_value(@lvalue, @method.init_value(node.inferred_type))
            end
          end
        end
      end
      
      def loop(loop, expression)
        if loop.redo? || loop.post || !loop.condition.predicate.expr?(self)
          loop = ComplexWhileLoop.new(loop, self)
        else
          loop = SimpleWhileLoop.new(loop, self)
        end
        with(:loop => loop) do
          loop.compile(expression)
        end
      end
      
      def expr?(target, params)
        !([target] + params).any? {|x| x.kind_of? Duby::AST::TempValue}
      end

      def operator(target, op, params, expression)
        simple = expr?(target, params)
        if expression && !simple
          @method.print @lvalue
        end
        if params.size == 0
          # unary operator
          op = op[0,1]
          @method.print op
          target.compile(self, true)
        else
          @method.print '('
          other = params[0]
          target.compile(self, true)
          @method.print " #{op} "
          other.compile(self, true)
          @method.print ')'
        end
        unless expression && simple
          @method.puts ';'
        end
      end

      def compile_args(call)
        call.parameters.map do |param|
          param.precompile(self)
        end
      end

      def self_type
        type = AST::type(@class.name.tr('/', '.'))
        type = type.meta if @static
        type
      end

      def super_call(call, expression)
        super_method_call(this, call, compile_args(call), expression)
      end

      def self_call(call, expression)
        if call.cast?
          args = compile_args(call)
          simple = call.expr?(self)
          @method.print @lvalue if expression && !simple
          @method.print "((#{call.inferred_type.name})("
          args.each{|arg| arg.compile(self, true)}
          @method.print "))"
          @method.puts ';' unless simple && expression
        else
          method_call(this, call, compile_args(call), expression)
        end
      end

      def call(call, expression)
        if Duby::AST::Constant === call.target
          target = call.target.inferred_type.name
        else
          target = call.target.precompile(self)
        end
        params = compile_args(call)
        
        if Operators.include? call.name
          operator(target, call.name, params, expression)
        elsif call.target.inferred_type.array? && ArrayOps.include?(call.name)
          array_op(target, call.name, params, expression)
        elsif call.name == 'nil?'
          operator(target, '==', ['null'], expression)
        else
          method_call(target, call, params, expression)
        end
      end
      
      def array_op(target, name, args, expression)
        simple = expr?(target, args)
        index, value = args
        if expression && !simple
          @method.print @lvalue
        end
        target.compile(self, true)
        if name == 'length'
          @method.print '.length'
        else
          @method.print '['
          index.compile(self, true)
          @method.print ']'
          if name == '[]='
            @method.print " = "
            value.compile(self, true)
          end
        end
        unless simple && expression
          @method.puts ';'
        end
      end
      
      def break(node)
        @loop.break
      end
      
      def next(node)
        @loop.next
      end
      
      def redo(node)
        @loop.redo
      end

      # TODO: merge cleanly with method_call logic
      def super_method_call(target, call, params, expression)
        simple = call.expr?(self)
        method = call.method(self)
        unless simple || method.actual_return_type.void?
          @method.print @lvalue if expression
        end
        if method.constructor?
          @method.print "super("
        else
          @method.print "super.#{method.name}("
        end
        params.each_with_index do |param, index|
          @method.print ', ' unless index == 0
          param.compile(self, true)
        end
        if simple && expression
          @method.print ')'
        else
          @method.puts ');'
        end
        if method.actual_return_type.void? && expression
          @method.print @lvalue
          if method.static?
            @method.puts 'null;'
          else
            target.compile(self, true)
            @method.puts ';'
          end
        end

      end
      
      def method_call(target, call, params, expression)
        simple = call.expr?(self)
        method = call.method(self)
        unless simple || method.actual_return_type.void?
          @method.print @lvalue if expression
        end
        if method.constructor?
          @method.print "new "
          target.compile(self, true)
          @method.print '('
        else
          target.compile(self, true)
          @method.print ".#{method.name}("
        end
        params.each_with_index do |param, index|
          @method.print ', ' unless index == 0
          param.compile(self, true)
        end
        if simple && expression
          @method.print ')'
        else
          @method.puts ');'
        end
        if method.actual_return_type.void? && expression
          @method.print @lvalue
          if method.static?
            @method.puts 'null;'
          else
            target.compile(self, true)
            @method.puts ';'
          end
        end
        
      end

      def temp(expression, value=nil)
        assign(@method.tmp(expression.inferred_type), value || expression)
      end

      def empty_array(type, size)
        sizevar = size.precompile(self)
        @method.print "#{@lvalue unless size.expr?(self)}new #{type.name}["
        sizevar.compile(self, true)
        @method.print ']'
      end

      def import(short, long)
      end

      def string(value)
        @method.print value.inspect
      end
      
      def boolean(value)
        @method.print value ? 'true' : 'false'
      end

      def array(node, expression)
        if expression
          # create unmodifiable list from array (simplest way to do this in Java source)
          @method.print "java.util.Collections.unmodifiableList(java.util.Arrays.asList("

          # elements, as expressions
          comma = false
          node.children.each do |n|
            @method.print ", " if comma
            n.compile(self, true)
            comma = true
          end
          
          @method.print("))")
        else
          # elements, as non-expressions
          # TODO: ensure they're all reference types!
          node.children.each do |n|
            n.compile(self, false)
          end
        end
      end
      
      def null
        @method.print 'null'
      end
      
      def compile_self
        @method.print 'this'
      end
      
      def print(node)
        value = node.parameters[0]
        value = value && value.precompile(self)
        if node.println
          @method.print "System.out.println("
        else
          @method.print "System.out.print("
        end
        value.compile(self, true) if value
        @method.puts ');'
      end

      def define_class(class_def, expression)
        with(:class => class_def.inferred_type.define(@file),
             :static => false) do
          @class.annotate(class_def.annotations)
          class_def.body.compile(self, false) if class_def.body
        
          @class.stop
        end
      end

      def with(vars)
        orig_values = {}
        begin
          vars.each do |name, new_value|
            name = "@#{name}"
            orig_values[name] = instance_variable_get name
            instance_variable_set name, new_value
          end
          yield
        ensure
          orig_values.each do |name, value|
            instance_variable_set name, value
          end
        end
      end
    end
  end
end
