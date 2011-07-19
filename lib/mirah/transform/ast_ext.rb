module Mirah
  module AST
    begin
      java_import 'mirah.impl.MirahParser'
    rescue NameError
      $CLASSPATH << File.dirname(__FILE__) + '/../../../javalib/mirah-parser.jar'
      java_import 'mirah.impl.MirahParser'
    end
    java_import 'jmeta.ErrorHandler'

    class MirahErrorHandler
      include ErrorHandler
      def warning(messages, positions)
        print "Warning: "
        messages.each_with_index do |message, i|
          jpos = positions[i]
          if jpos
            dpos = Mirah::Transform::Transformer::JMetaPosition.new(jpos, jpos)
            print "#{message} at "
            Mirah.print_error("", dpos)
          else
            print message
          end
        end
      end
    end

    def parse(src, filename='dash_e', raise_errors=false, transformer=nil)
      ast = parse_ruby(src, filename)
      transformer ||= Transform::Transformer.new(Mirah::Util::CompilationState.new)
      transformer.filename = filename
      ast = transformer.transform(ast, nil)
      if raise_errors
        transformer.errors.each do |e|
          raise e.cause || e
        end
      end
      ast
    end
    module_function :parse

    def parse_ruby(src, filename='-')
      raise ArgumentError if src.nil?
      parser = MirahParser.new
      parser.filename = filename
      parser.errorHandler = MirahErrorHandler.new
      begin
        parser.parse(src)
      rescue => ex
        if ex.cause.kind_of? Java::Jmeta::SyntaxError
          ex = SyntaxError.wrap ex.cause, nil
        end

        if ex.cause.respond_to? :position
          position = ex.cause.position
          Mirah.print_error(ex.cause.message, position)
        end
        raise ex
      end
    end
    module_function :parse_ruby
  end
end