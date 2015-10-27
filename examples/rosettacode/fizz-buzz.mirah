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


1.upto(100) do |n|
  print "Fizz" if a = ((n % 3) == 0)
  print "Buzz" if b = ((n % 5) == 0)
  print n unless (a || b)
  print "\n"
end

# a little more straight forward
1.upto(100) do |n|
    if (n % 15) == 0
        puts "FizzBuzz"
    elsif (n % 5) == 0
        puts "Buzz"
    elsif (n % 3) == 0
        puts "Fizz"
    else
        puts n
    end
end


