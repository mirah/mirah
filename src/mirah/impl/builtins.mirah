import duby.lang.compiler.Compiler

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

class Builtin
  defmacro new_hash(node) do
    items = node.child_nodes
    capacity = int(items.size * 0.84)
    capacity = 16 if capacity < 16
    literal = @duby.fixnum(capacity)
    hashmap = @duby.constant("java.util.HashMap")
    map = quote {`hashmap`.new(`literal`)}
    items.size.times do |i|
      next unless i % 2 == 0
      key = items.get(i)
      value = items.get(i + 1)
      map = quote {`map`.add(`key`, `value`)}
    end
    map
  end

  def self.initialize_builtins(mirah:Compiler)
    mirah.find_class("java.util.Map").load_extensions(Map.class)
  end
end