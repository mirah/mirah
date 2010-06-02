require 'duby'
module Duby
  class NbCompiler
    include org.jruby.duby.DubyCompiler
    
    class ParseResult
      ParseError = org.jruby.duby.ParseError
      
      include org.jruby.duby.ParseResult
      
      attr_reader :ast, :errors
      def initialize(ast, errors)
        @ast = ast
        parse_errors = errors.map do |error|
          ParseError.new(error.message, error.position)
        end
        @errors = parse_errors.to_java(ParseError)
      end
    end
    
    def parse(text)
      Duby::AST.type_factory = Duby::JVM::Types::TypeFactory.new
      ast = Duby::AST.parse_ruby(text)
      transformer = Duby::Transform::Transformer.new(Duby::CompilationState.new)
      return ParseResult.new(
          transformer.transform(ast, nil), transformer.errors)
    end
  end
end