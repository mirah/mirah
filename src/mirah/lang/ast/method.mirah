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

package mirahparser.lang.ast

interface FormalArgument < Named do
  def name:Identifier; end
  def type:TypeName; end
end

class Arguments < NodeImpl
  init_node do
    # Is there a better way to represent this?
    child_list required: RequiredArgument
    child_list optional: OptionalArgument
    child rest: RestArgument
    child_list required2: RequiredArgument
    child block: BlockArgument
  end
end

class RequiredArgument < NodeImpl
  implements FormalArgument
  init_node do
    child name: Identifier
    child type: TypeName
  end
end

class OptionalArgument < NodeImpl
  implements FormalArgument
  init_node do
    child name: Identifier
    child type: TypeName
    child value: Node
  end
end

class RestArgument < NodeImpl
  implements FormalArgument
  init_node do
    child name: Identifier
    child type: TypeName
  end
end

class BlockArgument < NodeImpl
  implements FormalArgument
  init_node do
    child name: Identifier
    child type: TypeName
    attr_accessor optional: 'boolean'
  end
end

class MethodDefinition < NodeImpl
  implements Named, Annotated
  init_node do
    child name: Identifier
    child arguments: Arguments
    child type: TypeName
    child body: Node
    child_list annotations: Annotation
    # exceptions
  end
end

class StaticMethodDefinition < MethodDefinition
  init_subclass(MethodDefinition)
end

class ConstructorDefinition < MethodDefinition
  init_subclass(MethodDefinition)
end