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

package mirah.lang.ast

class Body < NodeImpl
  init_list Node
end

class ClassAppendSelf < NodeImpl  # Better name? StaticScope or ClassScope maybe?
  init_list Node
end

class Block < NodeImpl
  init_node do
    child arguments: Arguments
    child body: Node
  end
end

class BindingReference < NodeImpl
  init_node
end

class Noop < NodeImpl
  init_node
end

class Script < NodeImpl
  init_node do
    child body: Node
  end
end

class Annotation < NodeImpl
  init_node do
    child name: Identifier
    child values: Hash
  end
end