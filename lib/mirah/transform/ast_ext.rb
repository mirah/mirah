module Mirah
  module AST
    java_import 'mirah.impl.MirahParser'
    java_import 'mirah.lang.ast.StringCodeSource'
    java_import 'org.mirah.macros.Macro'
    java_import 'org.mirah.util.SimpleDiagnostics'

    def parse(src, filename='dash_e', raise_errors=false, transformer=nil)
      raise ArgumentError unless transformer
      parse_ruby(transformer, src, filename)
    end
    module_function :parse

    def parse_ruby(transformer, src, filename='-')
      raise ArgumentError if src.nil?
      #filename = transformer.tag_filename(src, filename)
      parser = MirahParser.new
      source = StringCodeSource.new(filename, src)
      parser.diagnostics = SimpleDiagnostics.new(true)
      begin
        ast = parser.parse(source)
        if parser.diagnostics.error_count > 0
          puts "#{parser.diagnostics.error_count} errors, exiting"
          throw :exit, 1
        end
        return ast
      rescue NativeException => ex
        ex.cause.printStackTrace
        raise ex
      rescue => ex
        # if ex.cause.kind_of? Java::OrgMirahMmeta::SyntaxError
        #   ex = SyntaxError.wrap ex.cause, nil
        # end

        if ex.respond_to? :position
          position = ex.cause.position
          Mirah.print_error(ex.cause.message, position)
        end
        raise ex
      end
    end
    module_function :parse_ruby
  end
end
