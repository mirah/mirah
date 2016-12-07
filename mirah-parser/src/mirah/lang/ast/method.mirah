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

import java.util.Collections
import java.util.List

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
  
  def self.empty
    empty(nil)
  end
  
  def self.empty(position:Position)
    args = Arguments.new(position, Collections.emptyList, Collections.emptyList, nil,
                         Collections.emptyList, nil)
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
    child_list body: Node
    child_list annotations: Annotation
    child java_doc: Node
    # exceptions
  end

  def initialize(p:Position, name: Identifier, arguments: Arguments, type:TypeName, body: List, annotations: List)
    initialize(p, name, arguments, type, body, annotations, Node(nil))
  end

  def initialize(name: Identifier, arguments: Arguments, type:TypeName, body: List, annotations: List)
      initialize(name, arguments, type, body, annotations, Node(nil))
  end

end

class StaticMethodDefinition < MethodDefinition
  init_subclass(MethodDefinition)

  def initialize(p:Position, name: Identifier, arguments: Arguments, type:TypeName, body: List, annotations: List)
    initialize(p, name, arguments, type, body, annotations, Node(nil))
  end

  def initialize(name: Identifier, arguments: Arguments, type:TypeName, body: List, annotations: List)
      initialize(name, arguments, type, body, annotations, Node(nil))
  end
end

class ConstructorDefinition < MethodDefinition
  init_subclass(MethodDefinition)

  def initialize(p:Position, name: Identifier, arguments: Arguments, type:TypeName, body: List, annotations: List)
    initialize(p, name, arguments, type, body, annotations, Node(nil))
  end

  def initialize(name: Identifier, arguments: Arguments, type:TypeName, body: List, annotations: List)
      initialize(name, arguments, type, body, annotations, Node(nil))
  end
end

class Initializer < NodeImpl
  init_node do
    child_list body: Node
  end
end

# A node directly below a ClassDefinition node.
# The body is executed once per class initialization.
# This is used for dynamically initializing static fields.
#
# This is also useful for class-level macros which need to generate code
# which is to be executed once.
#
# For example, consider a class
#
#     class Foo
#       
#       class << self
#         attr_accessor bar:int
#       end
#       
#       on_static_init do
#         self.bar = 42
#       end
#     end
#
# Using the on_static_init macro, code can be executed once.
#
# This way, functionality of a static initializer as per https://docs.oracle.com/javase/specs/jls/se7/html/jls-8.html#jls-8.7 and as of this example  
#
#     class Foo {
#
#       static int bar;
#
#       static {
#         Foo.bar = 42;
#       }
#     }
#
# can be achieved.
#
class ClassInitializer < Initializer
  init_subclass(Initializer)
end

# A node directly below a ClassDefinition node.
# The body is to be executed once per object initialization.
#
# This is useful for class-level macros which need to generate code
# which is to be executed once per instance.
#
# The functionality should be similar to an instance initializer as per https://docs.oracle.com/javase/specs/jls/se7/html/jls-8.html#jls-8.6 and as of this example  
#
#     class Foo {
#
#       int bar;
#
#       {
#         this.bar = 42;
#       }
#     }
#
#
# However, support for ObjectInitializer is currently not implemented.
#
# class ObjectInitializer < Initializer
#   init_subclass(Initializer)
# end

