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
  class LocalDeclaration < Node
    include Named
    include Typed

    child :type_node
    attr_accessor :type

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      self.name = name
    end

    def infer(typer, expression)
      resolve_if(typer) do
        typer.get_scope(self) << name
        @type = type_node.type_reference(typer)
      end
    end

    def resolved!(typer)
      typer.learn_local_type(typer.containing_scope(self), name, @inferred_type)
      super
    end
  end

  class LocalAssignment < Node
    include Named
    include Valued

    child :value

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      self.name = name
    end

    def infer(typer, expression)
      resolve_if(typer) do
        typer.get_scope(self) << name
        type = typer.infer(value, true)
        if type && type.null?
          type = typer.local_type(containing_scope, name) unless typer.last_chance
        end
        type
      end
    end

    def resolved!(typer)
      typer.learn_local_type(typer.containing_scope(self), name, @inferred_type)
      super
    end
  end

  class Local < Node
    include Named

    def initialize(parent, line_number, name)
      super(parent, line_number, [])
      self.name = name
    end

    def infer(typer, expression)
      resolve_if(typer) do
        typer.get_scope(self) << name
        typer.local_type(typer.containing_scope(self), name)
      end
    end
  end
end