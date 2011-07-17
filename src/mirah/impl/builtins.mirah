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

import duby.lang.compiler.Compiler
import duby.lang.compiler.Node
import duby.lang.compiler.Body

class Map
  defmacro add(key, value) do
    quote do
      put(`key`, `value`)
      self
    end
  end

  macro def [](key)
    quote { get(`key`) }
  end

  macro def []=(key, value)
    quote { put(`key`, `value`) }
  end

  macro def empty?
    quote { isEmpty }
  end

  macro def keys
    quote { keySet }
  end
end

class ObjectExtension
  macro def loop(&block)
    quote do
      while true do
        `block.body`
      end
    end
  end
end

class Builtin
  defmacro new_hash(node) do
    items = Node(node.child_nodes.get(0)).child_nodes
    capacity = int(items.size * 0.84)
    capacity = 16 if capacity < 16
    literal = @mirah.fixnum(capacity)
    hashmap = @mirah.constant("java.util.HashMap")
    body = Body(quote {map = `hashmap`.new(`literal`);nil})
    items.size.times do |i|
      next unless i % 2 == 0
      key = items.get(i)
      value = items.get(i + 1)
      body << quote {map.put(`key`, `value`)}
    end
    body << quote {map}
  end

  def self.initialize_builtins(mirah:Compiler)
    mirah.find_class("java.util.Map").load_extensions(Map.class)
    mirah.find_class("java.lang.Object").load_extensions(ObjectExtension.class)
  end
end
