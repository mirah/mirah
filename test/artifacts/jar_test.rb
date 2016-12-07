# Copyright (c) 2010-2014 The Mirah project authors. All Rights Reserved.
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

require 'test_helper'

class JarTest < Test::Unit::TestCase
  def test_happy_path
  	out = `java -jar dist/mirahc.jar run -e 'puts 1'`
    assert_equal "1\n", out
  end

  def test_run_doesnt_exit_early
    out = `java -jar dist/mirahc.jar run -e 'Thread.new {Thread.sleep(1); puts 1}.start'`
    assert_equal "1\n", out
  end
end