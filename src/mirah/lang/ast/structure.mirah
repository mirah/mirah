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

class ClassAppendSelf < NodeImpl  # Better name? StaticScope or ClassScope maybe?
  init_node do
    child_list body: Node
  end
end

class Block < NodeImpl
  init_node do
    child arguments: Arguments
    child_list body: Node
  end
  
  def initialize(position:Position, arguments:Arguments, body:NodeList)
    initialize(position, arguments, java::util::Collections.emptyList)
    self.body = body
  end
end

class BindingReference < NodeImpl
  init_node
end

class Noop < NodeImpl
  init_node
end

# Is there any reason for this node?
class Script < NodeImpl
  init_node do
    child_list body: Node
  end
end

class Annotation < NodeImpl
  init_node do
    child type: TypeName
    child_list values: HashEntry
  end
end

class SyntheticLambdaDefinition < NodeImpl
  init_node do
    child supertype: TypeName # the supertype or superinterface the class generated for this block is to inherit
    child block:     Block
  end
end

