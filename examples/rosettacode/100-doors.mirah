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

class Door
	def initialize
		@state=false
	end

	def closed?; !@state; end
	def open?; @state; end

	def close; @state=false; end
	def open; @state=true; end

	def toggle
		if closed?
			open
		else
			close
		end
	end

	def toString; Boolean.toString(@state); end
end

doors=ArrayList.new
1.upto(100) do
    doors.add(Door.new)
end

1.upto(100) do |multiplier|
    index = 0
    doors.each do |door: Door|
        door.toggle if (index+1)%multiplier == 0
        index += 1
    end
end

i = 0
doors.each do |door|
    puts "Door #{i+1} is #{door}."
    i+=1
end
