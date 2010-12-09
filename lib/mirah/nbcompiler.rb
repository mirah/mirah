# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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