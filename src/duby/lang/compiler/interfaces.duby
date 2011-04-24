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

import java.util.List
import java.lang.Class as JavaClass

interface Node do
  def child_nodes
    returns List
  end

  def parent
    returns Node
  end

  # Returns the value of string-literalish nodes
  def string_value
    returns String
  end
end

interface Block < Node do
  def body
    returns Node
  end
end

interface Body < Node do
  def add_node(node:Node):void
  end

  macro def <<(node)
    quote { add_node(`node`) }
  end
end

interface Call < Node do
  def name
    returns String
  end

  def arguments
    returns List
  end

  def block
    returns Block
  end

  def target
    returns Node
  end
end

interface ClassDefinition < Node do
  def name
    returns String
  end

  def body
    returns Node
  end
end

interface MethodDefinition < Node do
  def body
    returns Node
  end
end

interface StringNode < Node do
  def literal
    returns String
  end
end

interface Macro do
  def expand
    returns Node
  end

  # defmacro quote(&block) do
  #   encoded = @mirah.dump_ast(block.body, @call)
  #   quote { @mirah.load_ast(`encoded`) }
  # end
  macro def quote(&block)
    encoded = @mirah.dump_ast(block.body, @call)
    code = <<RUBY
  call = eval("@mirah.load_ast(x)")
  call.parameters[0] = arg
  arg.parent = call
RUBY
    @mirah.__ruby_eval(code, encoded)
  end
end

interface Class do
  def load_extensions(from:JavaClass)
    returns void
  end
end

interface Compiler do
  macro def quote(&block)
    encoded = @mirah.dump_ast(block.body, @call)
    quote { load_ast(`encoded`) }
  end

  def find_class(name:String)
    returns Class
  end

  def defineClass(name:String, superclass:String)
    returns ClassDefinition
  end

  def defineClass(name:String, superclass:String, interfaces:List)
    returns ClassDefinition
  end

  def dump_ast(node:Node, call:Call)
    returns Object
  end

  def load_ast(serialized:Object)
    returns Node
  end

  def __ruby_eval(code:String, arg:Object)
    returns Node
  end

  def fixnum(x:int)
    returns Node
  end

  def body
    returns Body
  end

  def empty_array(type:Node, size:Node)
    returns Node
  end

  def constant(name:String)
    returns Node
  end

  def constant(name:String, array:boolean)
    returns Node
  end

  def string(value:String)
    returns StringNode
  end

  def cast(type:String, value:Node)
    returns Node
  end

  def cast(type:String, value:String)
    returns Node
  end
end

# abstract class Macro
#   abstract def expand
#     returns Node
#   end
# end