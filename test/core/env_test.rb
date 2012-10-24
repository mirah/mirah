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
require 'test_helper'

class EnvTest < Test::Unit::TestCase
  include Mirah

  def test_use_file_path_separator
    assert_equal(File::PATH_SEPARATOR, Mirah::Env.path_separator)
  end

  def test_encode_paths_joins_paths_with_path_separator
    abc = %w[a b c]
    assert_equal(abc.join(Mirah::Env.path_separator), Mirah::Env.encode_paths(abc))
  end

  def test_encode_paths_with_single_element
    assert_equal('a', Mirah::Env.encode_paths(['a']))
  end

  def test_encode_paths_with_empty_list
    assert_equal('', Mirah::Env.encode_paths([]))
  end

  def test_decode_paths_appends_to_second_arg
    paths_to_append = %w[a b c d]
    encoded_paths = paths_to_append.join Mirah::Env.path_separator
    path_array = ['1','2']

    assert_equal(['1','2','a','b','c','d'], Mirah::Env.decode_paths(encoded_paths, path_array))
    assert_equal(['1','2','a','b','c','d'], path_array)
  end

  def test_decode_paths_with_empty_list
    assert_equal([], Mirah::Env.decode_paths(''))
  end

  def test_decode_paths_with_single_element
    assert_equal(['a'], Mirah::Env.decode_paths('a'))
  end

end
