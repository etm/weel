require 'pp'
require 'rubygems'

# Damerau-Levenshtein distance with adjacent transpositions
# takes two arrays as input, array elements should have ::== and be comparable
# more info and sample implementation in other languages:
#  * http://dl.acm.org/citation.cfm?id=363994
#  * http://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance
def distance(source,target)
  combo = source.length + target.length

  score = Array.new(source.length+2)do |i|
    Array.new(target.length+2) do |j|
      i == 0 || j == 0 ? combo : i == 1 ? j -1 : j == 1 ? i - 1 : 0
    end
  end

  sd = Hash[(source + target).collect { |e| [e, 0] }]

  1.upto(source.length) do |i|
    db = 0
    1.upto(target.length) do |j|
      it = sd[target[j-1]]
      jt = db

      if (source[i-1] == target[j-1])
        score[i+1][j+1] = score[i][j]
        db = j
      else
        score[i+1][j+1] = [score[i][j],[score[i+1][j],score[i][j+1]].min].min + 1
      end

      score[i+1][j+1] = [score[i+1][j+1],score[it][jt]+(i-it-1)+1+(j-jt-1)].min
    end

    sd[source[i-1]] = i
  end

  score[source.length+1][target.length+1]
end

def move?(branches,a,b)
  branches.each do |branch|
    return false if branch.include?(a) && branch.include?(b) && branch.index(a) + 1 == branch.index(b)
  end
  true
end

def mix(branches)
  permutations = [ branches.flatten ]
  permutations_index = -1

  begin
    permutations_index += 1
    base = permutations[permutations_index].dup
    counter = 0
    while counter < base.length-1
      break if counter == base.length
      e1 = base[counter]
      e2 = base[counter+1]
      if move?(branches, e1, e2)
        base[counter], base[counter+1] = base[counter+1], base[counter]
        permutations << base.dup
      end 
      counter += 1
    end
    permutations = permutations.uniq
  end while permutations_index + 1 < permutations.length

  permutations
end

def std_cases(branches)
  run = []
  max = branches.max_by{ |b| b.length }.length
  0.upto(max-1) do |col|
    column = []
    branches.each do |branch|
      column << branch[col]
    end
    if run.empty?
      run = column.permutation.to_a
    else
      tmp = [] 
      column.permutation.each do |per|
        run.each do |tper|
          tmp << tper + per
        end
      end
      run = tmp
    end
  end
  run
end

# testset = [[:a,:b], [:c,:d], [:e,:f], [:g,:h]]
# testset = [[:a,:b], [:c,:d], [:g,:h]]
# testset = [[:a,:b], [:c,:d]]
# testset = [[:a,:b,:c], [:d,:e], [:f,:g]]
# testset = [[:a,:b, :c], [:d,:e,:f], [:g,:h,:i]]

# testset = [[:a,:b], [:d,:e], [:f,:g]]
#testset = [[:m,:n], [:m,:n]]
testset = [[:m,:n], [:m,:n], [:m, :n]]
stdcases = std_cases testset
stdcases.uniq!

result = mix testset

dists = result.collect do |res|
  stdcases.collect do |std|
    distance(std,res)
  end.min
end
maxdist = dists.max

puts "Testset:"
testset.each do |ts|
  puts "  Branch: #{ts.inspect}"
end
puts "Resulting Traces:"

possiblepieces = (1.0 - (1.0 / result.length)) / maxdist
result.each_with_index do |res,index|
  puts "#{res.inspect} #{dists[index]} #{1 - (possiblepieces * dists[index])}"
end

puts "Number of default traces: #{stdcases.length}"
puts "Total number of traces #{result.length}"
