require 'date'
@min_least_common_substring_length = 3

def longest_common_substring_length?(content, search)
  table = Array.new(search.length) { Array.new(content.length, 0) }
  result = ''
  longest = 0

  search.split('').each_with_index { |c0, i0|
    content.split('').each_with_index { |c1, i1|
      next unless c0.casecmp?(c1)
      table[i0][i1] = (i0 == 0 || i1 == 0) ? 1 : table[i0 - 1][i1 - 1] + 1
      if table[i0][i1] > longest
        longest = table[i0][i1]
        result = search[i0 - longest + 1, longest]
      end
    }
  }

  puts 'lcs analysis result: ' + result + ' ' + (longest >= @min_least_common_substring_length).to_s
  return longest >= @min_least_common_substring_length
end

puts longest_common_substring_length?("""Ask Question
  Asked 9 years, 3 months ago
  Active 1 year ago
  Viewed 212k times
  
  438
  
  
  61
  What is the easiest way to convert
  
  [x1, x2, x3, ... , xN]
  to
  
  [[x1, 2], [x2, 3], [x3, 4], ... , [xN, N+1]]
  ruby arrays indexing
  shareimprove this questionfollow
  edited May 14 '15 at 18:36
  
  the Tin Man
  145k2929 gold badges188188 silver badges269269 bronze badges
  asked Jan 15 '11 at 1:34
  
  Misha Moroshko
  136k193193 gold badges446446 silver badges674674 bronze badges
  add a comment
  10 Answers
  Active
  Oldest
  Votes
  
  829
  
  If you're using ruby 1.8.7 or 1.9, you can use the fact that iterator methods like each_with_index, when called without a block, return an Enumerator object, which you can call Enumerable methods like map on. So you can do:
  
  arr.each_with_index.map { |x,i| [x, i+2] }
  In 1.8.6 you can do:
  
  require 'enumerator'
  arr.enum_for(:each_with_index).map { |x,i| [x, i+2] }
  shareimprove this answerfollow
  edited Jan 15 '11 at 1:47
  answered Jan 15 '11 at 1:37
  
  sepp2k
  323k4545 gold badges626626 silver badges644644 bronze badges
  Thanks! Could you give me a pointer to documentation for .each_with_index.map ? – Misha Moroshko Jan 15 '11 at 1:41
  1
  @Misha: map is a method of Enumerable as always. each_with_index, when called without a block, returns an Enumerator object (in 1.8.7+), which mixes in Enumerable, so you can call map, select, reject etc. on it just like on an array, hash, range etc. – sepp2k Jan 15 '11 at 1:45
  8
  IMO this is simpler and better-reading in 1.8.7+: arr.map.with_index{ |o,i| [o,i+2] } – Phrogz Jan 15 '11 at 2:43 
  4
  @Phrogz: map.with_index doesn't work in 1.8.7 (map returns an array when called without a block in 1.8). – sepp2k Jan 15 '11 at 2:50
  2
  Important to note this doesn't work with .map! if you want to directly affect the array you're looping on. – Ash Blue Jul 25 '13 at 17:38
  show 4 more comments
  
  256
  
  Ruby has Enumerator#with_index(offset = 0), so first convert the array to an enumerator using Object#to_enum or Array#map:
  
  [:a, :b, :c].map.with_index(2).to_a
  #=> [[:a, 2], [:b, 3], [:c, 4]]
  shareimprove this answerfollow
  edited Nov 22 '18 at 8:29
  answered Jul 1 '12 at 9:26
  
  tokland
  57k1212 gold badges123123 silver badges154154 bronze badges
  11
  I believe this is the better answer, because it will work with map! foo = ['d'] * 5; foo.map!.with_index { |x,i| x * i }; foo #=> [\"\", \"d\", \"dd\", \"ddd\", \"dddd\"] – Connor McKay Feb 27 '14 at 21:47 
  add a comment
  
  129
  
  In ruby 1.9.3 there is a chainable method called with_index which can be chained to map.
  
  For example:
  
  array.map.with_index { |item, index| ... }
  shareimprove this answerfollow
  edited Apr 26 '19 at 10:42
  
  aristotll
  5,57055 gold badges2323 silver badges4343 bronze badges
  answered Oct 13 '14 at 7:56
  
  fruqi
  3,40522 gold badges2222 silver badges3131 bronze badges
  add a comment
  
  17
  
  Over the top obfuscation:
  
  arr = ('a'..'g').to_a
  indexes = arr.each_index.map(&2.method(:+))
  arr.zip(indexes)
  shareimprove this answerfollow
  answered Nov 10 '11 at 3:33
  
  Andrew Grimm
  65.6k4646 gold badges178178 silver badges298298 bronze badges
  12
  Andrew must have great job security! :) – David J. Jul 19 '12 at 6:36
  add a comment""", """
  _with_index).map { |x,i| [x, i+2] }
  shareimprove this answerfollow
  edited Jan 15 '11 at 1:47
  answered Jan 15 '11 at 1:37
  
  sepp2k
  323k4545 gold badges626626 silver badges644644 bronze badges
  Thanks! Could you give me a pointer to documentation for .each_with_index.map ? – Misha Moroshko Jan 15 '11 at 1:41
  1
  @Misha: map is a method of Enumerable as always. each_with_index, when called without a block, returns an Enumerator object (in 1.8.7+), which mixes in Enumerable, so you can call map, select, reject etc. on it just like on an array, hash, range etc. – sepp2k Jan 15 '11 at 1:45
  8
  IMO this is simpler and better-reading in 1.8.7+: arr.map.with_index{ |o,i| [o,i+2] } – Phrogz Jan 15 '11 at 2:43 
  4d
  @Phrogz: map.with_index doesn't work in 1.8.7 (map returns an array when called without a block in 1.8). – sepp2k Jan 15 '11 at 2:50
  2
  Important to note this doesn't work with .map! if you want to directly affect the array you're looping on. – Ash Blue Jul 25 '13 at 17:38
  show 4 more comments
  
  256
  
  Ruby has Enumerator#with_index(offset = 0), so first convert the array to an enumerator using Object#to_enum or Array#map:
  
  [:a, :b, :c].map.with_index(2).to_a
  #=> [[:a, 2], [:b, 3], [:c, 4]]
  shareimprove this answerfollow
""")