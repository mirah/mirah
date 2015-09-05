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

def run
  puts "Rendering"
  y = -39.0
  while y <= 39.0
    puts
    x = -39.0
    while x <= 39.0
      i = iterate(x/40.0,y/40.0)
      if (i == 0)
        print "*"
      else
        print " "
      end
      x += 1
    end
    y += 1
  end
  puts
end

def iterate(x:double,y:double)
  cr = y-0.5
  ci = x
  zi = 0.0
  zr = 0.0
  i = 0

  result = 0
  while true
    i += 1
    temp = zr * zi
    zr2 = zr * zr
    zi2 = zi * zi
    zr = zr2 - zi2 + cr
    zi = temp + temp + ci
    if (zi2 + zr2 > 16)
      result = i
      break
    end
    if (i > 1000)
      result = 0
      break
    end
  end

  result
end

i = 0
while i < 10
  start = System.currentTimeMillis
  run()
  puts "Time: #{(System.currentTimeMillis - start) / 1000.0}"
  i += 1
end
