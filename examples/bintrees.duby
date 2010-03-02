class BinaryTrees
  def self.main(args:String[])
    n = 0
    n = Integer.parseInt(args[0]) if args.length > 0

    maxDepth = (6 > n) ? 6 : n
    stretchDepth = maxDepth + 1

    check = TreeNode.bottomUpTree(0, stretchDepth).itemCheck
    puts "stretch tree of depth " + stretchDepth + "\t check: " + check

    longLivedTree = TreeNode.bottomUpTree 0, maxDepth

    depth = 4
    while depth <= maxDepth
      iterations = 1 << (maxDepth - depth + 4)
      check = 0

      i = 1
      while i <= iterations
        check += TreeNode.bottomUpTree(i, depth).itemCheck
        check += TreeNode.bottomUpTree(-i,depth).itemCheck
        i += 1
      end
      
      puts "" + iterations * 2 + "\t trees of depth " + depth + "\t check: " + check
      depth += 2
    end

    puts "long lived tree of depth " + maxDepth + "\t check: "+ longLivedTree.itemCheck
  end
end

class TreeNode
  def initialize(left:TreeNode, right:TreeNode, item:int)
    @item = item
    @left = left
    @right = right
  end

  def initialize(item:int)
    @left = TreeNode(nil)
    @right = TreeNode(nil)
    @item = item
  end

  def self.bottomUpTree(item:int, depth:int)
    if depth > 0
      TreeNode.new(
        TreeNode.bottomUpTree(2*item-1, depth-1),
        TreeNode.bottomUpTree(2*item, depth-1),
        item)
    else
      TreeNode.new(item)
    end
  end

  def itemCheck
    # if necessary deallocate here
    if @left == nil
      @item
    else
      @item + @left.itemCheck - @right.itemCheck
    end
  end
end
