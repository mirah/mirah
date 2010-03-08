import java.util.Collections
import java.util.ArrayList

list = ArrayList.new [9,5,2,6,8,5,0,3,6,1,8,3,6,4,7,5,0,8,5,6,7,2,3]
puts "unsorted: #{list}"
Collections.sort(list) {|a,b| Integer(a).compareTo(b)}
puts "sorted:   #{list}"
