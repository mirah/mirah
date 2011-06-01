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

module Mirah::AST
  class Import < Node
    attr_accessor :short
    attr_accessor :long
    def initialize(parent, line_number, short, long)
      @short = short
      @long = long
      super(parent, line_number, [])
    end

    def to_s
      "Import(#{short} = #{long})"
    end

    def infer(typer, expression)
      resolve_if(typer) do
        scope = typer.get_scope(self)
        scope.import(long, short)
        typer.type_reference(scope, @long) if short != '*'
        typer.no_type
      end
    end
  end

  defmacro('import') do |transformer, fcall, parent|
    case fcall.parameters.size
    when 1
      node = fcall.parameters[0]
      case node
      when String
        long = node.literal
        short = long[(long.rindex('.') + 1)..-1]
      when Call
        case node.parameters.size
        when 0
          pieces = [node.name]
          while Call === node
            node = node.target
            pieces << node.name
          end
          long = pieces.reverse.join '.'
          short = pieces[0]
        when 1
          arg = node.parameters[0]
          unless (FunctionalCall === arg &&
                  arg.name == 'as' && arg.parameters.size == 1)
            raise Mirah::TransformError.new("unknown import syntax", fcall)
          end
          short = arg.parameters[0].name
          pieces = [node.name]
          while Call === node
            node = node.target
            pieces << node.name
          end
          long = pieces.reverse.join '.'
        else
          raise Mirah::TransformError.new("unknown import syntax", fcall)
        end
      else
        raise Mirah::TransformError.new("unknown import syntax", fcall)
      end
    when 2
      short = fcall.parameters[0].literal
      long = fcall.parameters[1].literal
    else
      raise Mirah::TransformError.new("unknown import syntax", fcall)
    end
    Import.new(parent, fcall.position, short, long)
  end

  defmacro('package') do |transformer, fcall, parent|
    node = fcall.parameters[0]
    block = fcall.block
    case node
    when String
      name = node.literal
    when Call
      pieces = [node.name]
      block ||= node.block
      while Call === node
        node = node.target
        pieces << node.name
        block ||= node.block
      end
      name = pieces.reverse.join '.'
    when FunctionalCall
      name = node.name
      block ||= node.block
    else
      raise Mirah::TransformError.new("unknown package syntax", fcall)
    end
    if block
      raise Mirah::TransformError.new("unknown package syntax", block)
      body = Body.new(parent, fcall.position)
      new_scope = transformer.typer.add_scope(body)
      new_scope.package = name
      body << block.body
    else
      transformer.get_scope(fcall).package = name
      Noop.new(parent, fcall.position)
    end
  end

  class EmptyArray < Node
    attr_accessor :size
    attr_accessor :component_type
    child :type_node
    child :size

    def initialize(*args)
      super(*args)
    end

    def infer(typer, expression)
      resolve_if(typer) do
        @component_type = type_node.type_reference(typer)
        typer.infer(size, true)
        typer.type_reference(nil, @component_type, true)
      end
    end
  end

  class Builtin < Node
    def infer(typer, expression)
      resolve_if(typer) {Mirah::AST.type(nil, 'mirah.impl.Builtin')}
    end
  end
end