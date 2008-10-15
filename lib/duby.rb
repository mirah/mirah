require 'duby/transform'
require 'duby/ast'
require 'duby/typer'
require 'duby/compiler'
begin
  require 'jvmscript'
rescue LoadError
  $: << File.dirname(__FILE__) + '/../../jvmscript/lib'
  require 'jvmscript'
end
require 'duby/jvm_compiler'
Dir[File.dirname(__FILE__) + "/duby/plugin/*"].each {|file| require "#{file}" if file =~ /\.rb$/}
require 'jruby'

module Duby
  def self.run(*args)
    java.lang.System.set_property("jruby.duby.enabled", "true")
    
    process_flags!(args)
    filename = args.shift
    
    if filename == '-e'
      filename = 'dash_e'
      ast = Duby::AST.parse(args[0])
    else
      ast = Duby::AST.parse(File.read(filename))
    end

    typer = Duby::Typer::Simple.new(:script)
    ast.infer(typer)
    typer.resolve(true)

    compiler = Duby::Compiler::JVM.new(filename)
    ast.compile(compiler, false)

    compiler.generate {|filename, builder|
      bytes = builder.generate
      cls = JRuby.runtime.jruby_class_loader.define_class(builder.class_name.gsub(/\//, '.'), bytes.to_java_bytes)
      main_method = cls.get_method("main", [java.lang.String[].java_class].to_java(java.lang.Class))
      main_method.invoke(nil, [args.to_java(:string)].to_java)
    }
  end
  
  def self.compile(*args)
    java.lang.System.set_property("jruby.duby.enabled", "true")
    
    process_flags!(args)
    filename = args.shift
    
    if filename == '-e'
      filename = 'dash_e'
      ast = Duby::AST.parse(args[0])
    else
      ast = Duby::AST.parse(File.read(filename))
    end

    typer = Duby::Typer::Simple.new(:script)
    ast.infer(typer)
    typer.resolve(true)

    compiler = Duby::Compiler::JVM.new(filename)
    ast.compile(compiler, false)

    compiler.generate {|filename, builder|
      bytes = builder.generate
      File.open(filename, 'w') {|f| f.write(bytes)}
    }
  end
  
  def self.process_flags!(args)
    while args.length > 0
      case args[0]
      when '-V'
        Duby::Typer.verbose = true
        Duby::AST.verbose = true
        Duby::Compiler::JVM.verbose = true
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