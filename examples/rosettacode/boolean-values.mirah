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

import java.util.ArrayList
import java.util.HashMap

# booleans
puts 'true is true' if true
puts 'false is false' if (!false)

# lists treated as booleans
x = ArrayList.new
puts "empty array is true" if x
x.add("an element")
puts "full array is true" if x
puts "isEmpty() is false" if !x.isEmpty()

# maps treated as booleans
map = HashMap.new
puts "empty map is true" if map
map.put('a', '1')
puts "full map is true" if map
puts "size() is 0 is false" if !(map.size() == 0)

# these things do not compile
# value = nil   # ==> cannot assign nil to Boolean value
# puts 'nil is false' if false == nil  # ==> cannot compare boolean to nil
# puts '0 is false' if (0 == false)    # ==> cannot compare int to false

#puts 'TRUE is true' if TRUE   # ==> TRUE does not exist
#puts 'FALSE is false' if !FALSE   # ==> FALSE does not exist

