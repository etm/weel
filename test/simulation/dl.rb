require 'pp'

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

p distance('ac'.split(''),'cba'.split(''))
