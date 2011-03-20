module Mirah
  class Impl
    def initialize
      Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    end
    
    def run(*args)
      main = nil
      class_map = {}
      
      # generate all bytes for all classes
      generate(args) do |outfile, builder|
        bytes = builder.generate
        name = builder.class_name.gsub(/\//, '.')
        class_map[name] = bytes
      end
      
      # load all classes
      dcl = Mirah::ClassLoader.new(JRuby.runtime.jruby_class_loader, class_map)
      class_map.each do |name,|
        cls = dcl.load_class(name)
        # TODO: using first main; find correct one
        main ||= cls.get_method("main", java::lang::String[].java_class) #rescue nil
      end
      
      # run the main method we found
      if main
        begin
          main.invoke(nil, [args.to_java(:string)].to_java)
        rescue java.lang.Exception => e
          e = e.cause if e.cause
          raise e
        end
      else
        puts "No main found" unless @state.version_printed || @state.help_printed
      end
    rescue Mirah::InternalCompilerError => ice
      Mirah.print_error(ice.message, ice.position) if ice.node
      raise ice
    rescue Mirah::MirahError => ex
      Mirah.print_error(ex.message, ex.position)
      puts ex.backtrace if @state.verbose
    end
    
    def compile(*args)
      generate(args) do |filename, builder|
        filename = "#{@state.destination}#{filename}"
        FileUtils.mkdir_p(File.dirname(filename))
        bytes = builder.generate
        File.open(filename, 'wb') {|f| f.write(bytes)}
      end
    rescue Mirah::InternalCompilerError => ice
      Mirah.print_error(ice.message, ice.position) if ice.position
      puts "error on #{ice.node}(#{ice.node.object_id})"
      raise ice
    rescue Mirah::MirahError => ex
      Mirah.print_error(ex.message, ex.position)
      puts ex.backtrace if @state.verbose
    end
    
    def generate(args, &block)
      process_flags!(args)
      
      # collect all ASTs from all files
      all_nodes = []
      expand_files(args).each do |duby_file|
        if duby_file == '-e'
          @filename = '-e'
          next
        elsif @filename == '-e'
          all_nodes << parse('-e', duby_file)
        else
          all_nodes << parse(duby_file)
        end
        @filename = nil
        exit 1 if @error
      end
      
      # enter all ASTs into inference engine
      infer_asts(all_nodes)
      
      # compile each AST in turn
      all_nodes.each do |ast|
        compile_ast(ast, &block)
      end
    end
    
    def parse(*args)
      process_flags!(args)
      @filename = args.shift
      
      if @filename
        if @filename == '-e'
          @filename = 'DashE'
          src = args[0]
        else
          src = File.read(@filename)
        end
      else
        print_help
        exit(1)
      end
      begin
        ast = Mirah::AST.parse_ruby(src, @filename)
        # rescue org.jrubyparser.lexer.SyntaxException => ex
        #   Mirah.print_error(ex.message, ex.position)
        #   raise ex if @state.verbose
      end
      @transformer = Mirah::Transform::Transformer.new(@state)
      Java::MirahImpl::Builtin.initialize_builtins(@transformer)
      @transformer.filename = @filename
      ast = @transformer.transform(ast, nil)
      @transformer.errors.each do |ex|
        Mirah.print_error(ex.message, ex.position)
        raise ex.cause || ex if @state.verbose
      end
      @error = @transformer.errors.size > 0
      
      ast
    rescue Mirah::InternalCompilerError => ice
      Mirah.print_error(ice.message, ice.position) if ice.node
      raise ice
    rescue Mirah::MirahError => ex
      Mirah.print_error(ex.message, ex.position)
      puts ex.backtrace if @state.verbose
    end
    
    def infer_asts(asts)
      typer = Mirah::Typer::JVM.new(@transformer)
      asts.each {|ast| typer.infer(ast, true) }
      begin
        typer.resolve(false)
      ensure
        puts asts.inspect if @state.verbose
        
        failed = !typer.errors.empty?
        if failed
          puts "Inference Error:"
          typer.errors.each do |ex|
            if ex.node
              Mirah.print_error(ex.message, ex.position)
            else
              puts ex.message
            end
            puts ex.backtrace if @state.verbose
          end
          exit 1
        end
      end
    end
    
    def compile_ast(ast, &block)
      compiler = @compiler_class.new
      ast.compile(compiler, false)
      compiler.generate(&block)
    end
    
    def process_flags!(args)
      @state ||= Mirah::CompilationState.new
      while args.length > 0 && args[0] =~ /^-/
        case args[0]
        when '--classpath', '-c'
          args.shift
          Mirah::Env.decode_paths(args.shift, $CLASSPATH)
        when '--cd'
          args.shift
          Dir.chdir(args.shift)
        when '--dest', '-d'
          args.shift
          @state.destination = File.join(File.expand_path(args.shift), '')
        when '-e'
          break
        when '--explicit-packages'
          args.shift
          Mirah::AST::Script.explicit_packages = true
        when '--help', '-h'
          print_help
          args.clear
        when '--java', '-j'
          require 'mirah/jvm/source_compiler'
          @compiler_class = Mirah::Compiler::JavaSource
          args.shift
        when '--jvm'
          args.shift
          @state.set_jvm_version(args.shift)
        when '-I'
          args.shift
          $: << args.shift
        when '--plugin', '-p'
          args.shift
          plugin = args.shift
          require "mirah/plugin/#{plugin}"
        when '--verbose', '-V'
          Mirah::Typer.verbose = true
          Mirah::AST.verbose = true
          Mirah::Compiler::JVM.verbose = true
          @state.verbose = true
          args.shift
        when '--version', '-v'
          args.shift
          print_version
        when '--no-save-extensions'
          args.shift
          @state.save_extensions = false
        else
          puts "unrecognized flag: " + args[0]
          print_help
          args.clear
        end
      end
      @state.destination ||= File.join(File.expand_path('.'), '')
      @compiler_class ||= Mirah::Compiler::JVM
    end
    
    def print_help
      puts "#{$0} [flags] <files or -e SCRIPT>
      -c, --classpath PATH\tAdd PATH to the Java classpath for compilation
      --cd DIR\t\tSwitch to the specified DIR befor compilation
      -d, --dir DIR\t\tUse DIR as the base dir for compilation, packages
      -e CODE\t\tCompile or run the inline script following -e
      \t\t\t  (the class will be named \"DashE\")
      --explicit-packages\tRequire explicit 'package' lines in source
      -h, --help\t\tPrint this help message
      -I DIR\t\tAdd DIR to the Ruby load path before running
      -j, --java\t\tOutput .java source (compile mode only)
      --jvm VERSION\t\tEmit JVM bytecode targeting specified JVM
      \t\t\t  version (1.4, 1.5, 1.6, 1.7)
      -p, --plugin PLUGIN\trequire 'mirah/plugin/PLUGIN' before running
      -v, --version\t\tPrint the version of Mirah to the console
      -V, --verbose\t\tVerbose logging"
      @state.help_printed = true
    end
    
    def print_version
      puts "Mirah v#{Mirah::VERSION}"
      @state.version_printed = true
    end
    
    def expand_files(files)
      expanded = []
      files.each do |filename|
        if File.directory?(filename)
          Dir[File.join(filename, '*')].each do |child|
            if File.directory?(child)
              files << child
            elsif child =~ /\.(duby|mirah)$/
              expanded << child
            end
          end
        else
          expanded << filename
        end
      end
      expanded
    end
  end
end