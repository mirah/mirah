module Mirah
  module AST
    begin
      java_import 'mirah.impl.MirahParser'
    rescue NameError
      $CLASSPATH << File.dirname(__FILE__) + '/../../../javalib/mirah-parser.jar'
      java_import 'mirah.impl.MirahParser'
    end
    java_import 'org.mirah.mmeta.ErrorHandler'

    class MirahErrorHandler
      include ErrorHandler
      def initialize(transformer)
        @transformer = transformer
      end
      def warning(messages, positions)
        print "Warning: "
        messages.each_with_index do |message, i|
          jpos = positions[i]
          if jpos
            dpos = Mirah::Transform::Transformer::JMetaPosition.new(@transformer, jpos, jpos)
            print "#{message} at "
            Mirah.print_error("", dpos)
          else
            print message
          end
        end
      end
    end

    def parse(src, filename='dash_e', raise_errors=false, transformer=nil)
      transformer ||= Transform::Transformer.new(Mirah::Util::CompilationState.new)
      parse_ruby(transformer, src, filename)
    end
    module_function :parse

    def parse_ruby(transformer, src, filename='-')
      raise ArgumentError if src.nil?
      filename = transformer.tag_filename(src, filename)
      parser = MirahParser.new
      parser.filename = filename
      parser.errorHandler = MirahErrorHandler.new(transformer)
      begin
        parser.parse(src)
      rescue => ex
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