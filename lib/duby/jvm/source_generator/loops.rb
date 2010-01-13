class Duby::Compiler::JavaSource
  class NoRedoError < StandardError; end

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
      raise NoRedoError, "#{self.class.name} doesn't support redo"
    end
    
    def compile(expression)
      prepare
      @loop.init.compile(compiler, false) if @loop.init?
      @start.call
      compiler.method.block do
        @loop.pre.compile(compiler, false) if @loop.pre?
        compile_body
        @loop.post.compile(compiler, false) if @loop.post?
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

  class ComplexWhileLoop < SimpleWhileLoop

    def prepare
      super
      @outer = compiler.method.label
      @inner = compiler.method.label
      @complex_predicate = !loop.condition.predicate.expr?(compiler)
      super_start = @start
      @start = lambda do
        compiler.method.puts "#{@outer}:"
        super_start.call
      end
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
      if @loop.redo
        compiler.method.puts "#{@redo} = true;"
        compiler.method.puts "continue #{@inner};"
      else
        super
      end
    end
  end
end