require 'duby'
require 'duby/ast'
require 'duby/jvm/types'
require 'duby/jvm/compiler'
require 'duby/jvm/source_generator/builder'

module Duby
  module Compiler
    class JavaSource
      JVMTypes = Duby::JVM::Types
      include Duby::Compiler::JVM::JVMLogger
      attr_accessor :filename, :method, :static, :class, :lvalue
      
      Calls = [
        Duby::AST::Call,
        Duby::AST::FunctionalCall,
      ]
      Expressions = [
        Duby::AST::Constant,
        Duby::AST::Field,
        Duby::AST::Literal,
        Duby::AST::Local,
      ]
      Operators = [
        '+', '-', '+@', '-@', '/', '%', '*', '<', '<=', '==', '>=', '>',
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
        classname = parts.pop.sub /[.].+/, ''
        package = parts.join('.') unless parts.empty?

        @file = Duby::JavaSource::Builder.new(filename, self)
        @file.package = package
        @class = @file.public_class(classname)
      end

      def generate(&block)
        @class.stop
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
        with :method => @class.main do
          log "Starting main method"

          @method.start

          body.compile(self, false)

          @method.stop
        end

        log "Main method complete!"
      end

      def define_method(name, signature, args, body)
        args = args.args || []
        return_type = signature[:return]
        if @static
          method = @class.public_static_method(name.to_s, return_type, *args)
        else
          if name == "initialize"
            method = @class.public_constructor(*args)
          else
            method = @class.public_method(name.to_s, return_type, *args)
          end
        end

        with :method => method do
          log "Starting new method #{name}"

          @method.start

          unless @method.type.nil? || @method.type.void?
            self.return(ImplicitReturn.new(body))
          else
            body.compile(self, false) if body
          end
        
          log "Method #{name} complete!"
          @method.stop
        end
      end

      def return(node)
        if @method.type.nil? || @method.type.void?
          @method.puts 'return;'
          return
        end
        
        store_value('return ', node.value)
      end

      def line(num)
      end
      
      def declare_local(name, type)
        @method.declare_local(type, name)
      end
      
      def declare_field(name, type)
        @class.declare_field(name, type, @static)
      end

      def local(name, type)
        @method.print name
      end
      
      def field(name, type)
        name = name[1..-1]
        declare_field(name, type)
        @method.print "#{this}.#{name}"
      end

      def this
        @static ? @class.class_name : 'this'
      end

      def local_assign(name, type, expression, value)
        declare_local(name, type)

        lvalue = "#{@lvalue if expression}#{name} = "
        store_value(lvalue, value)
      end

      def field_declare(name, type)
        name = name[1..-1]
        declare_field(name, type)
      end
      
      def local_declare(name, type)
        declare_local(name, type)
      end
      
      def field_assign(name, type, expression, value)
        name = name[1..-1]
        declare_field(name, type)
        lvalue = "#{@lvalue if expression}#{this}.#{name} = "
        store_value(lvalue, value)
      end
      
      def store_value(lvalue, value)
        case value
        when *Expressions
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
        maybe_store(body.children[last], expression)
      end
      
      def branch(node, expresson)
        predicate = temp(node.condition.predicate)
        @method.block "if (#{predicate})" do
          maybe_store(node.body, expresson) if node.body
        end
        if node.else
          @method.block 'else' do
            maybe_store(node.else, expresson)
          end
        end
      end
      
      def loop(loop, expression)
        predicate = @method.tmp(JVMTypes::Boolean)
        assign(predicate, loop.condition.predicate) if loop.check_first
        negative = loop.negative ? '!' : ''
        check = "while (#{negative}#{predicate})"
        if loop.check_first
          start = check
        else
          start = 'do'
        end
        @method.block start do
          with(:redo => @method.tmp(JVMTypes::Boolean),
               :loop => @method.label) do
            @method.block "#{@loop}:" do
              loop.body.compile(self, false)
            end
            @method.block "if (#{@redo})" do
              @method.puts "#{predicate} = true;"
            end
            @method.block "else" do
              assign(predicate, loop.condition.predicate)
            end
          end
        end
        unless loop.check_first
          @method.print check
          @method.puts ';'
        end
        if expression
          @method.puts "#{@lvalue}null;"
        end
      end

      def operator(target, op, params, expression)
        @method.print @lvalue if expression
        if params.size == 0
          # unary operator
          op = op[0].chr
          @method.print "#{op}#{target}"
        else
          @method.print "#{target} #{op} #{params[0]}"
        end
        @method.puts ';'
      end

      def compile_args(call)
        args = call.parameters.map do |param|
          temp(param)
        end
        types = call.parameters.map {|p| p.inferred_type}
        [args, types]
      end

      def self_call(call, expression)
        type = AST::type(@class.name)
        type = type.meta if @static
        method_call(this, call.name, compile_args(call), type, expression)
      end

      def call(call, expression)
        if Duby::AST::Constant === call.target
          target = call.target.inferred_type.name
        else
          target = temp(call.target)
        end
        params = compile_args(call)
        
        if Operators.include? call.name
          operator(target, call.name, params, expression)
        elsif call.target.inferred_type.array? && ArrayOps.include?(call.name)
          array_op(target, call.name, params, expression)
        elsif call.name == 'nil?'
          operator(target, '==', ['null'], expression)
        else
          method_call(target, call.name, params,
                      call.target.inferred_type, expression)
        end
      end
      
      def array_op(target, name, args, expression)
        (index, value), = args
        @method.print "#{@lvalue if expression}#{target}"
        if name == 'length'
          @method.print '.length'
        else
          @method.print"[#{index}]"
          if name == '[]='
            @method.print " = #{value}"
          end
        end
        @method.puts ';'
      end
      
      def break
        @method.puts "break;"
      end
      
      def next
        @method.puts "break #{@loop};"
      end
      
      def redo
        @method.puts "#{@redo} = true;"
        @method.puts "break #{@loop};"
      end
      
      def method_call(target, name, args, target_type, expression)
        params, types = args
        method = target_type.get_method(name, types)
        unless method.return_type.nil?
          @method.print @lvalue if expression
        end
        if method.constructor?
          @method.print "new #{target}("
        else
          @method.print "#{target}.#{method.name}("
        end
        params.each_with_index do |name, index|
          @method.print ', ' unless index == 0
          @method.print name
        end
        @method.puts ');'
        if method.return_type.nil? && expression
          @method.print @lvalue
          if method.static?
            @method.puts 'null;'
          else
            @method.puts "#{target};"
          end
        end
        
      end

      def temp(expression)
        assign(@method.tmp(expression.inferred_type), expression)
      end

      def empty_array(type, size)
        sizevar = temp(size)
        @method.puts "#{@lvalue}new #{type.name}[#{sizevar}];"
      end

      def import(short, long)
      end

      def string(value)
        @method.print value.inspect
      end
      
      def boolean(value)
        @method.print value ? 'true' : 'false'
      end
      
      def null
        @method.print 'null'
      end
      
      def println(node)
        value = node.parameters[0]
        @method.puts "System.out.println(#{temp(value) if value});"
      end

      def define_class(class_def, expression)
        with(:class => class_def.inferred_type.define(@file),
             :static => false) do
          class_def.body.compile(self, false)
        
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
