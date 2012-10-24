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

import java.math.BigInteger
import java.util.PriorityQueue

def updateFrontier(x:BigInteger, queue:PriorityQueue):void
    queue.offer(x.shiftLeft(1))
    queue.offer(x.multiply(BigInteger.valueOf(3)))
    queue.offer(x.multiply(BigInteger.valueOf(5)))
end

def hamming(n:int):BigInteger
    raise "Invalid parameter" if (n <= 0)

    frontier = PriorityQueue.new
    updateFrontier(BigInteger.ONE, frontier)
    lowest = BigInteger.ONE
    1.upto(n-1) do | i |
        lowest = BigInteger(frontier.poll())
        while (frontier.peek().equals(lowest))
            frontier.poll()
        end
        updateFrontier(lowest, frontier)
    end
    lowest
end


nums = ""
1.upto(20) do | i |
     nums = nums + " #{hamming(i)}"
end
puts "Hamming(1 .. 20) =#{nums}"
puts "\nHamming(1691) = #{hamming(1691)}"
puts "Hamming(1000000) = #{hamming(1000000)}"

