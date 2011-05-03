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

# class Condition < NodeImpl
#   child predicate: Node
# end

class If < NodeImpl
  init_node do
    child condition: Node
    child body: Node
    child elseBody: Node
  end
end

# Should this be split into multiple nodes?
class Loop < NodeImpl
  init_node do
    child init: Body
    child condition: Node
    child pre: Body
    child body: Body
    child post: Body
    attr_accessor checkFirst: 'boolean', negative: 'boolean'
  end
end

class Not < NodeImpl
  init_node do
    child value: Node
  end
end

class Return < NodeImpl
  init_node do
    child value: Node
  end
end

class Break < NodeImpl
  init_node
end

class Next < NodeImpl
  init_node
end

class Redo < NodeImpl
  init_node
end

class Raise < NodeImpl
  init_node do
    child_list args: Node
  end
end

class RescueClause < NodeImpl
  init_node do
    child types: TypeNameList
    child name: Identifier
    child body: Node
  end
end

class Rescue < NodeImpl
  init_node do
    child body: Node
    child_list clauses: RescueClause
  end
end

class Ensure < NodeImpl
  init_node do
    child body: Node
    child ensureClause: Node
  end
end