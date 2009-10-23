class Duby::Compiler::JavaSource
  class SimpleWhileLoop
    attr_reader :compiler, :loop
    def initialize(loop, compiler)
      @loop = loop
      @compiler = compiler
    end
    
    def break
      compiler.method.puts "break;"
    end
    
    def next
      compiler.method.puts "continue;"
    end
    
    def redo
      raise "#{self.class.name} doesn't support redo"
    end
    
    def compile(expression)
      prepare
      @start.call
      compiler.method.block do
        compile_body
      end
      if @end_check
        @end_check.call
        compiler.method.puts ';'
      end
      if expression
        compiler.method.puts "#{compiler.lvalue}null;"
      end
    end
    
    def compile_body
      loop.body.compile(compiler, false)
    end
    
    def prepare
      predicate = loop.condition.predicate.precompile(compiler)
      negative = loop.negative ? '!' : ''
      check = lambda do
        compiler.method.print "while (#{negative}"
        predicate.compile(compiler, true)
        compiler.method.print ')'
      end
      if loop.check_first
        @start = check
      else
        @start = lambda {compiler.method.print 'do'}
        @end_check = check
      end
    end
  end

  module Redoable
    def compile_with_redo(block)
      @redo = compiler.method.tmp(JVMTypes::Boolean)
      compiler.method.puts "#{@inner}:"
      compiler.method.block "do" do
        compiler.method.puts "#{@redo} = false;"
        block.compile(compiler, false)
      end
      compiler.method.puts "while (#{@redo});"
    end

    def break
      compiler.method.puts "break #{@outer};"
    end
    
    def next
      compiler.method.puts "break #{@inner};"
    end
    
    def redo
      compiler.method.puts "#{@redo} = true;"
      compiler.method.puts "continue #{@inner};"
    end
  end

  class ComplexWhileLoop < SimpleWhileLoop
    include Redoable
    def prepare
      super
      @outer = compiler.method.label
      @inner = compiler.method.label
      @complex_predicate = !loop.condition.predicate.expr?(compiler)
      compiler.method.puts "#{@outer}:"
    end

    def compile_body
      if @loop.redo
        compile_with_redo(@loop.body)
      else
        compiler.method.puts "#{@inner}:"
        compiler.method.block do
          loop.body.compile(compiler, false)
        end
      end
    end
  end
  
  class SimpleForLoop < SimpleWhileLoop
    def prepare
      iter = loop.iter.precompile(compiler)
      iter_type = loop.iter.inferred_type
      if iter_type.array?
        type = iter_type.component_type.to_source
      else
        type = "java.lang.Object"
      end
      name = loop.var.name
      @start = lambda do
        compiler.method.print "for (#{type} #{name} : "
        iter.compile(compiler, true)
        compiler.method.print ')'
      end
    end
  end

  class RedoableForLoop < SimpleForLoop
    include Redoable
    def prepare
      super
      @outer = compiler.method.label
      @inner = compiler.method.label
      compiler.method.puts "#{@outer}:"
    end

    def compile_body
      compiler.method.puts "#{@inner}:"
      compile_with_redo(@loop.body)
    end
  end
end