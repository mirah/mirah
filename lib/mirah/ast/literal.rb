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
  class Array < Node
    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer)
      children.each do |kid|
        kid.infer(typer)
      end
      @inferred_type = typer.array_type
    end
  end

  class Fixnum < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      resolve_if(typer) {@inferred_type = typer.fixnum_type(@literal)}
    end

    def ==(other)
      @literal == other.literal
    end

    def eql?(other)
      self.class == other.class && @literal.eql?(other.literal)
    end
  end

  class Float < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      resolve_if(typer) {@inferred_type = typer.float_type(@literal)}
    end
  end

  class Hash < Node; end

  class Regexp < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.regexp_type
    end
  end

  class String < Node
    include Literal
    include Scoped
    include Java::DubyLangCompiler.StringNode

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.string_type
    end

    def type_reference(typer)
      typer.type_reference(scope, @literal)
    end

    def toString
      @literal
    end
  end

  class StringConcat < Node
    def initialize(parent, position, &block)
      super(parent, position, &block)
    end

    def infer(typer)
      unless resolved?
        resolved = true
        children.each {|node| node.infer(typer); resolved &&= node.resolved?}
        resolved! if resolved
        @inferred_type ||= typer.string_type
      end
      @inferred_type
    end
  end

  class ToString < Node
    child :body

    def initialize(parent, position)
      super(parent, position)
    end

    def infer(typer)
      unless resolved?
        body.infer(typer)
        resolved! if body.resolved?
        @inferred_type ||= typer.string_type
      end
      @inferred_type
    end
  end

  class Symbol < Node; end

  class Boolean < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.boolean_type
    end
  end

  class Null < Node
    include Literal

    def initialize(parent, line_number)
      super(parent, line_number)
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.null_type
    end
  end
end