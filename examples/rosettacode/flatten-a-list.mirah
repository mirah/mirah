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
import java.util.List
import java.util.Collection

def flatten(list: Collection)
    flatten(list, ArrayList.new)
end
def flatten(source: Collection, result: List)

    source.each do |x|
        if (Collection.class.isAssignableFrom(x.getClass()))
            flatten(Collection(x), result)
        else
            result.add(x)
            result  # if branches must return same type
        end
    end
    result
end

# creating a list-of-list-of-list fails currently, so constructor calls are needed
source = [[1], 2, [[3, 4], 5], [[ArrayList.new]], [[[6]]], 7, 8, ArrayList.new]

puts flatten(source)
