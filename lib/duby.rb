require 'duby/transform'
require 'duby/ast'
require 'duby/typer'
require 'duby/compiler'
begin
  require 'bitescript'
rescue LoadError
  $: << File.dirname(__FILE__) + '/../../bitescript/lib'
  require 'bitescript'
end
require 'duby/jvm/compiler'
require 'duby/jvm/typer'
Dir[File.dirname(__FILE__) + "/duby/plugin/*"].each {|file| require "#{file}" if file =~ /\.rb$/}
require 'jruby'

module Duby
  def self.run(*args)
    ast = parse(*args)

    main_cls = nil
    compile_ast(ast) do |outfile, builder|
      bytes = builder.generate
      name = builder.class_name.gsub(/\//, '.')
      cls = JRuby.runtime.jruby_class_loader.define_class(name, bytes.to_java_bytes)
      proxy_cls = JavaUtilities.get_proxy_class(name)
      # TODO: using first main; find correct one
      if proxy_cls.respond_to? :main
        main_cls ||= proxy_cls
      end
    end
    
    if main_cls
      main_cls.main(args.to_java(:string))
    else
      puts "No main found"
    end
  end
  
  def self.compile(*args)
    ast = parse(*args)

    compile_ast(ast) {|filename, builder|
      bytes = builder.generate
      File.open(filename, 'w') {|f| f.write(bytes)}
    }
  end
  
  def self.parse(*args)
    java.lang.System.set_property("jruby.duby.enabled", "true")
    
    process_flags!(args)
    $filename = args.shift

    Duby::AST.type_factory = Duby::JVM::Types::TypeFactory.new
    if $filename == '-e'
      $filename = 'dash_e'
      ast = Duby::AST.parse(args[0])
    else
      ast = Duby::AST.parse(File.read($filename))
    end
    ast
  end
  
  def self.compile_ast(ast, &block)
    compiler = $compiler_class.new($filename)
    typer = Duby::Typer::JVM.new(compiler)
    ast.infer(typer)
    typer.resolve(true)

    ast.compile(compiler, false)
    compiler.generate(&block)
  end
  
  def self.process_flags!(args)
    $compiler_class = Duby::Compiler::JVM
    while args.length > 0
      case args[0]
      when '-V'
        Duby::Typer.verbose = true
        Duby::AST.verbose = true
        Duby::Compiler::JVM.verbose = true
        args.shift
      when '-java'
        require 'duby/jvm/source_compiler'
        $compiler_class = Duby::Compiler::JavaSource
        args.shift
      else
        break
      end
    end
  end
end

if __FILE__ == $0
  Duby.run(ARGV[0], *ARGV[1..-1])
end