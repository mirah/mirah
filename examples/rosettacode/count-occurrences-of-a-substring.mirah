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


import java.util.regex.Pattern
import java.util.regex.Matcher

#The "remove and count the difference" method
def count_substring(pattern:String, source:String)
    (source.length() - source.replace(pattern, "").length()) / pattern.length()
end

puts count_substring("th", "the three truths")      # ==> 3
puts count_substring("abab", "ababababab")          # ==> 2
puts count_substring("a*b", "abaabba*bbaba*bbab")   # ==> 2


# The "split and count" method
def count_substring2(pattern:String, source:String)
    # the result of split() will contain one more element than the delimiter
	# the "-1" second argument makes it not discard trailing empty strings
    source.split(Pattern.quote(pattern), -1).length - 1
end

puts count_substring2("th", "the three truths")      # ==> 3
puts count_substring2("abab", "ababababab")          # ==> 2
puts count_substring2("a*b", "abaabba*bbaba*bbab")   # ==> 2


# This method does a match and counts how many times it matches
def count_substring3(pattern:String, source:String)
    result = 0
    Matcher m = Pattern.compile(Pattern.quote(pattern)).matcher(source);
    while (m.find())
        result = result + 1
    end
    result
end

puts count_substring3("th", "the three truths")      # ==> 3
puts count_substring3("abab", "ababababab")          # ==> 2
puts count_substring3("a*b", "abaabba*bbaba*bbab")   # ==> 2


