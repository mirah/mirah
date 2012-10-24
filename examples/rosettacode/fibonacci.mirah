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


def fibonacci(n:int)
    return n if n < 2
    fibPrev = 1
    fib = 1
    3.upto(Math.abs(n)) do
        oldFib = fib
        fib = fib + fibPrev
        fibPrev = oldFib
    end
    fib * (n<0 ? int(Math.pow(n+1, -1)) : 1)
end

puts fibonacci 1
puts fibonacci 2
puts fibonacci 3
puts fibonacci 4
puts fibonacci 5
puts fibonacci 6
puts fibonacci 7

