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

# Example of using a dynamic type in a method definition
def foo(a:dynamic)
  puts "I got a #{a.getClass.getName} of size #{a.size}"
end

class SizeThing
  def initialize(size:int)
    @size = size
  end

  def size
    @size
  end
end

foo([1,2,3])
foo(SizeThing.new(12))
