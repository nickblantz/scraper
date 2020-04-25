class SuffixTree
  def initialize(text, mon)
    @mon = mon
    @text = text
    [ @root_class = Class.new(RootSegment),
      @base_class = Class.new(BaseSegment),
      @branch_class = Class.new(InternalSegment),
      @leaf_class = Class.new(LeafSegment) 
    ].each do |c|
      c.instance_exec(@text) do |txt|
        define_method(:text) do
          txt
        end
      end
    end
    @root=@root_class.new
    @root.link = @base = @base_class.new(@root)
    @base.link = @base
  end
end