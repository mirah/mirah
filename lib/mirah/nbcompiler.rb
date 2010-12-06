require 'mirah'
module Mirah
  class NbCompiler
    include org.mirah.DubyCompiler

    class ParseResult
      ParseError = org.mirah.ParseError

      include org.mirah.ParseResult

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
      Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
      ast = Mirah::AST.parse_ruby(text)
      transformer = Mirah::Transform::Transformer.new(Mirah::CompilationState.new)
      return ParseResult.new(
          transformer.transform(ast, nil), transformer.errors)
    end
  end
end