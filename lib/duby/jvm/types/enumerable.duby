module Enumerable
  defmacro :all?(&block) do |duby, call|
    block = call.block || duby.block {|x| x}
    all = duby.tmp  # returns a unique name
    block.body = duby.eval do
      # backticks refernce AST Nodes from the surrounding scope
      unless `block.body`
        `all` = false
        break
      end
    end
    the_loop = duby.for(block, call.target)
    duby.eval do
      `all` = true
      `the_loop`
      `all`
    end
  end
  alias all? all?(&b)

  # Or with hygenic macros instead of temporary variables.
  defmacro any?(target, &block=nil) do |duby|
    block ||= duby.block {|x| x}
    var = block.args[0]

    duby.eval do
      any = false
      `target`.each do |`var`|
        if `block.body`
          any = true
          break
        end
      end
      any
    end
  end

  defmacro each_with_index(&block) do |duby|
    var, index = args[0], block.args[1]
    duby.eval do
      `index` = 0
      # `self` could mean call.target?
      `self`.each do |`var`|
        `block.body`
        after {`index` += 1}
      end
    end
  end
end

class Iterable
  defmacro each(&block) do |duby|
    var = block.args[0] || duby.tmp
    duby.eval do
      it = `self`.iterator
      while it.hasNext
        before {`var` = it.next}
        `block.body`  # or perhaps just `block`
      end
    end
  end
end