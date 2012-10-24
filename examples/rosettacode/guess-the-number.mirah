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

def getInput:int
    s = System.console.readLine()
    Integer.parseInt(s)
end


number = int(Math.random() * 10 + 1)

puts "guess the number between 1 and 10"
guessed = false
while !guessed do
    userNumber = getInput
    if userNumber == number
        guessed = true
        puts "you guessed it"
    elsif userNumber > number
        puts "too high"
    else
        puts "too low"
    end
end
