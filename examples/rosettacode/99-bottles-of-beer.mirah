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


plural = 's'
99.downto(1) do |i|
  puts "#{i} bottle#{plural} of beer on the wall,"
  puts "#{i} bottle#{plural} of beer"
  puts "Take one down, pass it around!"
  plural = '' if i - 1 == 1
  if i > 1
    puts "#{i-1} bottle#{plural} of beer on the wall!"
    puts
  else
    puts "No more bottles of beer on the wall!"
  end
end
