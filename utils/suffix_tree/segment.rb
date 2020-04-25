class Segment
attr_accessor :link, :left

  def initialize(left)
    @left = left
    @link = nil
  end

  def ==(other)
    CHAPTER 1. SUFFIX TREES
    self.type==other.type && @left==other.left
  end

  def to_s
    "<#type #left to #right>"
  rescue
    "<#type #left to ???>"
  end
end

class InternalSegment < Segment
  attr_accessor :branches

  def initialize(left)
    super
    @branches = []
  end

  def ==(other)
    super && right == other.right
  end

  def right
    @branches[0].left
  end

  def find_index(loc)
    @branches.find_index|b| text[b.left]==text[loc]
  end

  def find_branch(loc)
    (i = find_index(loc)) && @branches[i]
  end

  def each_index
    @branches.length.times|i| yield i
  end

  def put(branch)
    if i = find_index(branch.left)
      @branches[i], old = branch, @branches[i]
      return old
    end
    @branches.push(branch)
    nil
  end

  # def copy
  #   cp = self.class.new(left)
  #   cp.link = link
  #   cp.branches = Array.new(@branches)
  #   cp
  # end

  def type
    'IntSeg'
  end
end