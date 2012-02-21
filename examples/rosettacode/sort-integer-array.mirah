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

import java.util.Arrays
import java.util.ArrayList
import java.util.Collections

# Sorting arrays
nums = [2, 4, 3, 1, 2].toArray
puts Arrays.toString(nums)
Arrays.sort(nums)
puts Arrays.toString(nums)


# Sorting collections and lists

# list literals are immutable, so make an ArrayList
list = ArrayList.new
list.addAll([2,4,3,1,2])
puts list
Collections.sort(list)
puts list

