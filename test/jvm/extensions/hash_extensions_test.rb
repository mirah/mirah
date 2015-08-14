# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

class HashExtensionsTest < Test::Unit::TestCase

  def test_hash_each_untyped
    cls, = compile(%q{
    	res = java::util::TreeSet.new # stable sort order of the results
    	
      {
        a: "b",
        "c" => "d",
        "e" => 3,
        [4] => "h"
      }.each do |k,v|
        res.add("#{v},#{k}")
      end
      	
      res.each do |r|
      	puts r
      end
    })
    assert_run_output("3,e\nb,a\nd,c\nh,[4]\n", cls)
  end

  def test_hash_each_typed
    cls, = compile(%q{
    	res = java::util::TreeSet.new # stable sort order of the results

      {
        "a" => 3,
        "b" => 2
      }.each do |k:String,v:int|
        res.add("#{v+1},#{k}")
      end

      res.each do |r|
      	puts r
      end
    })
    assert_run_output("3,b\n4,a\n", cls)
  end
end

