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

require 'mirah'
require 'mirah/ast'
require 'mirah/jvm/types'
require 'mirah/jvm/compiler'
require 'mirah/jvm/source_generator/builder'
require 'mirah/jvm/source_generator/precompile'
require 'mirah/jvm/source_generator/loops'

class String
  def compile(compiler, expression)
    compiler.method.print self if expression
  end
end

module Mirah
  module JVM
    module Compiler
      class JavaSource < Base
        JVMTypes = Mirah::JVM::Types
        attr_accessor :lvalue

        Operators = [
          '+', '-', '+@', '-@', '/', '%', '*', '<',
          '<=', '==', '!=', '>=', '>',
          '<<', '>>', '>>>', '|', '&', '^', '~'
        ]
        ArrayOps = [
          '[]', '[]=', 'length'
        ]

        ImplicitReturn = Struct.new(:value)

        def initialize(scoper, typer)
          super
        end

        def logger_name
          "org.mirah.ruby.JVM.Compiler.JavaSource"
        end

        def file_builder(filename)
          Mirah::JavaSource::Builder.new(filename, self)
        end

        def output_type
          "source files"
        end
        
        def define_class(class_def, expression)
          with(:type => class_def.inferred_type,
          :class => class_def.inferred_type.define(@file),
          :static => false) do
            annotate(@class, class_def.annotations)
            class_def.body.compile(self, false) if class_def.body
            @class.stop unless @method && @method.name == 'main' && @class == @method.klass
          end
        end
        
        def define_method(node)
          base_define_method(node, false) do |method, _|
            with :method => method do
              log "Starting new method #{node.name}"
              @method.start

              prepare_binding(node) do
                declare_locals(get_scope(node))
                unless @method.returns_void?
                  self.return(ImplicitReturn.new(node.body))
                else
                  visit(node.body, false) if node.body
                end
              end

              log "Method #{node.name} complete!"
              @method.stop
            end
          end
        end
        
        def annotate(node, annotations)
          node.annotate(annotations)
        end

        def define_optarg_chain(name, arg, return_type,
          args_for_opt, arg_types_for_opt)
          # declare all args so they get their values
          @method.print "return " unless method.returns_void?
          @method.print "this." unless @static
          @method.print "#{name}("
          @method.print args_for_opt.map(&:name).join(', ')
          @method.print ', 'if args_for_opt.size > 0
          visit(arg.value, true)

          # invoke the next one in the chain
          @method.print ");\n"
        end

        def constructor(node)
          super(node, false) do |method, _|
            with :method => method do
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
                  visit(arg, true)
                end
                method.puts ");"
              end

              prepare_binding(node) do
                declare_locals(get_scope(node))
                visit(node.body, false) if node.body
              end
              method.stop
            end
          end
        end

        def prepare_binding(node)
          scope = introduced_scope(node)
          if scope.has_binding?
            type = scope.binding_type
            @binding = @bindings[type]
            @method.puts "#{type.to_source} $binding = new #{type.to_source}();"
            if node.respond_to? :arguments
              node.arguments.args.each do |param|
                if scope.captured?(param.name)
                  captured_local_declare(scope, param.name, inferred_type(param))
                  @method.puts "$binding.#{param.name} = #{param.name};"
                end
              end
            end
          end
          begin
            yield
          ensure
            if scope.has_binding?
              @binding.stop
              @binding = nil
            end
          end
        end

        def visitClosureDefinition(class_def, expression)
          compiler = ClosureCompiler.new(@file, @type, self)
          compiler.visitClassDefinition(class_def, expression)
        end

        def visitReturn(node, expression)
          if method.returns_void?
            @method.puts 'return;'
            return
          end

          if node.value.expr?(self)
            @method.print 'return '
            visit(node.value, true)
            @method.puts ';'
          else
            store_value('return ', node.value)
          end
        end

        def _raise(node)
          if node.expr?(self)
            @method.print 'throw '
            visit(node, true)
            @method.puts ';'
          else
            store_value('throw ', node)
          end
        end

        def rescue(node, expression)
          @method.block 'try' do
            if node.else_node.nil?
              maybe_store(node.body, expression) if node.body
            else
              visit(node.body, false) if node.body
            end
          end
          node.clauses.each do |clause|
            clause.types.each do |type|
              name = scoped_local_name(clause.name || 'tmp$ex', introduced_scope(clause))
              @method.declare_local(type, name, false)
              @method.block "catch (#{type.to_source} #{name})" do
                declare_locals(introduced_scope(clause))
                maybe_store(clause.body, expression)
              end
            end
          end
          if node.else_node
            maybe_store(node.else_node, expression)
          end
        end

        def ensure(node, expression)
          @method.block 'try' do
            maybe_store(node.body, expression)
          end
          @method.block 'finally' do
            visit(node.clause, false)
          end
        end

        def line(num)
        end

        def declare_local(name, type)
          @method.declare_local(type, name)
        end

        def declare_field(name, type, annotations, static_field)
          @class.declare_field(name, type, @static || static_field, 'private', annotations)
        end

        def local(scope, name, type)
          name = scoped_local_name(name, scope)
          @method.print name
        end

        def visitFieldAccess(field, expression)
          return unless expression
          name = field.name
          declare_field(name, inferred_type(field), field.annotations, field.isStatic)
          @method.print "#{this}.#{name}"
        end

        def this(scope=nil, method=nil)
          if method && method.static?
            method.declaring_class.name
          elsif scope.nil?
            @static ? @class.class_name : 'this'
          elsif scope.self_node && scope.self_node != :self
            scoped_local_name('self', scope)
          elsif scope.self_type.meta?
            scope.self_type.name
          else
            'this'
          end
        end

        def declare_locals(scope)
          scope.locals.each do |name|
            full_name = scoped_local_name(name, scope)
            unless scope.captured?(name) || method.local?(full_name)
              declare_local(full_name, scope.local_type(name))
            end
          end
        end

        def local_assign(scope, name, type, expression, value)
          simple = value.expr?(self)
          value = value.precompile(self)
          name = scoped_local_name(name, scope)
          if method.local?(name)
            if expression
              if simple
                @method.print '('
              else
                @method.print @lvalue
              end
            end
            @method.print "#{name} = "
            visit(value, true)
            if simple && expression
              @method.print ')'
            else
              @method.puts ';'
            end
          else
            @method.declare_local(type, name) do
              visit(value, true)
            end
            if expression
              @method.puts "#{@lvalue}#{name};"
            end
          end
        end

        def visitFieldDeclaration(decl, expression)
          declare_field(decl.name, inferred_type(decl), decl.annotations, decl.isStatic)
        end

        def local_declare(scope, name, type)
          name = scoped_local_name(name, scope)
          declare_local(name, type)
        end

        def visitFieldAssign(field, expression)
          name = field.name
          declare_field(field.name, inferred_type(field), field.annotations, field.isStatic)
          lvalue = "#{@lvalue if expression}#{this}.#{name} = "
          store_value(lvalue, field.value)
        end

        def captured_local_declare(scope, name, type)
          unless declared_captures[name]
            declared_captures[name] = type
            @binding.declare_field(name, type, false, '')
          end
        end

        def captured_local(scope, name, type)
          captured_local_declare(scope, name, type)
          @method.print "$binding.#{name}"
        end

        def captured_local_assign(node, expression)
          scope, name, type = containing_scope(node), node.name, inferred_type(node)
          captured_local_declare(scope, name, type)
          lvalue = "#{@lvalue if expression}$binding.#{name} = "
          store_value(lvalue, node.value)
        end

        def store_value(lvalue, value)
          if value.is_a? String
            @method.puts "#{lvalue}#{value};"
          elsif value.expr?(self)
            @method.print lvalue
            visit(value, true)
            @method.puts ';'
          else
            with :lvalue => lvalue do
              visit(value, true)
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
            visit(value, false)
          end
        end

        def body(body, expression)
          super(body, expression) do |last|
            maybe_store(last, expression)
          end
        end

        def scoped_body(scope, expression)
          if @method
            @method.block do
              super
            end
          else
            super
          end
        end

        def branch_expression(node)
          visit(node.condition, true)
          @method.print ' ? ('
          if node.body
            visit(node.body, true)
          else
            @method.print @method.init_value(inferred_type(node))
          end
          @method.print ') : ('
          if node.elseBody
            visit(node.elseBody, true)
          else
            @method.print @method.init_value(inferred_type(node))
          end
          @method.print ')'
        end

        def visitIf(node, expression)
          if expression && node.expr?(self)
            return branch_expression(node)
          end
          predicate = node.condition.precompile(self)
          @method.print 'if ('
          visit(predicate, true)
          @method.block ")" do
            if node.body
              maybe_store(node.body, expression)
            elsif expression
              store_value(@lvalue, @method.init_value(inferred_type(node)))
            end
          end
          if node.elseBody || expression
            @method.block 'else' do
              if node.elseBody
                maybe_store(node.elseBody, expression)
              else
                store_value(@lvalue, @method.init_value(inferred_type(node)))
              end
            end
          end
        end

        def visitLoop(loop, expression)
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
          !([target] + params).any? {|x| x.kind_of? Mirah::AST::TempValue}
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
            visit(target, true)
          else
            @method.print '('
            other = params[0]
            visit(target, true)
            @method.print " #{op} "
            visit(other, true)
            @method.print ')'
          end
          unless expression && simple
            @method.puts ';'
          end
        end

        def precompile_nodes(nodes)
          if nodes.all? {|n| n.expr?(self)}
            nodes
          else
            nodes.map do |node|
              tempval = node.precompile(self)
              if node == tempval && !node.kind_of?(Mirah::AST::Literal)
                tempval = node.temp(self)
              end
              tempval
            end
          end
        end

        def compile_args(call)
          precompile_nodes(call.parameters)
        end

        def self_type
          type = AST.type(nil, @class.name.tr('/', '.'))
          type = type.meta if @static
          type
        end

        def super_call(call, expression)
          super_method_call(this(get_scope(call)), call, compile_args(call), expression)
        end

        def visitCast(call, expression)
          args = compile_args(call)
          simple = call.expr?(self)
          @method.print @lvalue if expression && !simple
          @method.print "((#{inferred_type(call).to_source})("
          args.each{|arg| visit(arg, true)}
          @method.print "))"
          @method.puts ';' unless simple && expression
        end

        def visitFunctionalCall(call, expression)
          type = get_scope(call).self_type
          type = type.meta if (@static && type == @type)
          params = call.parameters.map do |param|
            inferred_type(param)
          end
          method = type.get_method(call.name, params)
          method_call(this(get_scope(call), method), call, compile_args(call), expression)
        end

        def visitCall(call, expression)
          return cast(call, expression) if call.cast?
          if Mirah::AST::Constant === call.target || Mirah::AST::Colon2 === call.target
            target = call.inferred_type(target).to_source
          else
            target = call.precompile_target(self)
          end
          params = compile_args(call)

          if Operators.include? call.name
            operator(target, call.name, params, expression)
          elsif call.inferred_type(target).array? && ArrayOps.include?(call.name)
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
          visit(target, true)
          if name == 'length'
            @method.print '.length'
          else
            @method.print '['
            visit(index, true)
            @method.print ']'
            if name == '[]='
              @method.print " = "
              visit(value, true)
            end
          end
          unless simple && expression
            @method.puts ';'
          end
        end

        def break(node)
          error("break outside of loop", node) unless @loop
          @loop.break
        end

        def next(node)
          error("next outside of loop", node) unless @loop
          @loop.next
        end

        def redo(node)
          error("redo outside of loop", node) unless @loop
          @loop.redo
        end

        # TODO: merge cleanly with method_call logic
        def super_method_call(target, call, params, expression)
          simple = call.expr?(self)
          method = call.method(self)
          unless simple || method.return_type.void?
            @method.print @lvalue if expression
          end
          if method.constructor?
            @method.print "super("
          else
            @method.print "super.#{method.name}("
          end
          params.each_with_index do |param, index|
            @method.print ', ' unless index == 0
            visit(param, true)
          end
          if simple && expression
            @method.print ')'
          else
            @method.puts ');'
          end
          if method.return_type.void? && expression
            @method.print @lvalue
            if method.static?
              @method.puts 'null;'
            else
              visit(target, true)
              @method.puts ';'
            end
          end

        end

        def method_call(target, call, params, expression)
          simple = call.expr?(self)
          method = call.method(self)
          unless simple || method.return_type.void?
            @method.print @lvalue if expression
          end

          # preamble
          if method.constructor?
            @method.print "new "
            visit(target, true)
            @method.print '('
          elsif method.field?
            visit(target, true)
            @method.print ".#{method.name}"
            if method.argument_types.size == 1
              @method.print " = ("
            end
          elsif Mirah::JVM::Types::Intrinsic === method
            method.call(self, call, expression)
            return
          else
            @method.print "("             if Mirah::AST::StringConcat === target
            visit target, true
            @method.print ")"             if Mirah::AST::StringConcat === target
            @method.print ".#{method.name}("
          end

          # args
          params.each_with_index do |param, index|
            @method.print ', ' unless index == 0
            visit(param, true)
          end

          # postamble
          if !method.field? || (method.field? && method.argument_types.size == 1)
            if simple && expression
              @method.print ')'
            else
              @method.puts ');'
            end
          end

          # cleanup
          if method.return_type.void? && expression
            @method.print @lvalue
            if method.static?
              @method.puts 'null;'
            else
              visit(target, true)
              @method.puts ';'
            end
          end
        end

        def temp(expression, value=nil)
          value ||= expression
          type = inferred_type(value)
          if value.expr?(self)
            @method.tmp(type) do
              visit(value, true)
            end
          else
            assign(@method.tmp(type), value)
          end
        end

        def empty_array(type, size)
          sizevar = size.precompile(self)
          @method.print "#{@lvalue unless size.expr?(self)}new #{type.name}["
          visit(sizevar, true)
          @method.print ']'
        end

        def string(value)
          @method.print value.inspect
        end

        def boolean(value)
          @method.print value ? 'true' : 'false'
        end

        def regexp(value, flags = 0)
          @method.print "java.util.regex.Pattern.compile("
          @method.print value.inspect
          @method.print ")"
        end

        def array(node, expression)
          if expression
            # create unmodifiable list from array (simplest way to do this in Java source)
            @method.print "java.util.Collections.unmodifiableList(java.util.Arrays.asList("

            # elements, as expressions
            comma = false
            node.children.each do |n|
              @method.print ", " if comma
              visit(n, true)
              comma = true
            end

            @method.print("))")
          else
            # elements, as non-expressions
            # TODO: ensure they're all reference types!
            node.children.each do |n|
              visit(n, false)
            end
          end
        end

        def build_string(orig_nodes, expression)
          if expression
            nodes = precompile_nodes(orig_nodes)
            simple = nodes.equal?(orig_nodes)

            unless simple
              @method.print(lvalue)
            end

            @method.print '"" + ' unless nodes.first.kind_of?(Mirah::AST::String)

            visit(nodes.first, true)

            nodes[1..-1].each do |node|
              @method.print ' + '
              visit(node, true)
            end

            unless simple
              @method.puts ';'
            end
          else
            orig_nodes.each {|n| visit(n, false)}
          end
        end

        def to_string(body, expression)
          visit(body, expression)
        end

        def null
          @method.print 'null'
        end

        def binding_reference
          @method.print '$binding'
        end

        def real_self
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
          visit(value, true) if value
          @method.puts ');'
        end

        class ClosureCompiler < JavaSource
          def initialize(file, type, parent)
            @file = file
            @type = type
            @parent = parent
            @scopes = parent.scopes
          end

          def prepare_binding(node)
            scope = introduced_scope(node)
            if scope.has_binding?
              type = scope.binding_type
              @binding = @parent.get_binding(type)
              @method.puts("#{type.to_source} $binding = this.binding;")
            end
            begin
              yield
            ensure
              if scope.has_binding?
                @binding = nil
              end
            end
          end

          def declared_captures
            @parent.declared_captures(@binding)
          end
        end
      end
    end
  end
end
