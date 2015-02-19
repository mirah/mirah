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

import java.util.List

# class Condition < NodeImpl
#   child predicate: Node
# end


class Case < NodeImpl
  init_node do
     # The value to compare against for the when clauses
    child condition: Node
    child_list clauses: Node # really WhenClause
    child_list elseBody: Node
  end
end

class WhenClause < NodeImpl
  init_node do
    child_list candidates: Node # possible matching elements
    child_list body: Node
  end
end

class If < NodeImpl
  init_node do
    child condition: Node
    child_list body: Node
    child_list elseBody: Node
  end
end

# Should this be split into multiple nodes?
class Loop < NodeImpl
  init_node do
    child_list init: Node
    child condition: Node
    child_list pre: Node
    child_list body: Node
    child_list post: Node
    attr_accessor skipFirstCheck: 'boolean', negative: 'boolean'
  end

  def initialize(position:Position, condition:Node, body:List, negative:boolean, skipFirstCheck:boolean)
    self.position = position
    self.init = NodeList.new
    self.condition = condition
    self.pre = NodeList.new
    self.body = NodeList.new(body)
    self.post = NodeList.new
    self.negative = negative
    self.skipFirstCheck = skipFirstCheck
  end
end

class Not < NodeImpl
  init_node do
    child value: Node
  end
  def toString
    "Not value:#{value}"
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
    child_list types: TypeName
    child name: Identifier
    child_list body: Node
  end
end

class Rescue < NodeImpl
  init_node do
    child_list body: Node
    child_list clauses: RescueClause
    child_list elseClause: Node
  end
end

class Ensure < NodeImpl
  init_node do
    child_list body: Node
    child_list ensureClause: Node
  end
end