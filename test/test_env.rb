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

require 'test/unit'
require 'mirah'

class TestEnv < Test::Unit::TestCase
  include Mirah

  def test_path_seperator
    # Check that env var PATH_SEPERATOR is used
    RbConfig::CONFIG['PATH_SEPARATOR'] = '*'
    assert_equal('*', Mirah::Env.path_seperator)

    # Check that : (colon) is returned if no PATH_SEPERATOR env var set
    RbConfig::CONFIG['PATH_SEPARATOR'] = ''
    assert_equal(':', Mirah::Env.path_seperator)
  end

  def test_encode_paths
    RbConfig::CONFIG['PATH_SEPARATOR'] = ':'
    
    assert_equal('a:b:c', Mirah::Env.encode_paths(['a','b','c']))
    assert_equal('a', Mirah::Env.encode_paths(['a']))
    assert_equal('', Mirah::Env.encode_paths([]))

    RbConfig::CONFIG['PATH_SEPARATOR'] = ';'

    assert_equal('a;b;c', Mirah::Env.encode_paths(['a','b','c']))
  end

  def test_decode_paths
    RbConfig::CONFIG['PATH_SEPARATOR'] = ':'

    path_array = ['1','2']
    assert_equal(['1','2','a','b','c','d'], Mirah::Env.decode_paths('a:b:c:d', path_array))
    assert_equal(['1','2','a','b','c','d'], path_array)

    assert_equal(['a','b','c','d'], Mirah::Env.decode_paths('a:b:c:d'))
    assert_equal(['a'], Mirah::Env.decode_paths('a'))

    RbConfig::CONFIG['PATH_SEPARATOR'] = ';'
    assert_equal(['a','b','c','d'], Mirah::Env.decode_paths('a;b;c;d'))
  end
end