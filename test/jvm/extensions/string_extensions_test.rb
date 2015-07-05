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

class StringExtensionsTest < Test::Unit::TestCase

  def test_string_concat
    cls, = compile("
      def str_str; a = 'a'; b = 'b'; a + b; end
      def str_boolean; a = 'a'; b = false; a + b; end
      def str_float; a = 'a'; b = float(1.0); a + b; end
      def str_double; a = 'a'; b = 1.0; a + b; end
      def str_byte; a = 'a'; b = byte(1); a + b; end
      def str_short; a = 'a'; b = short(1); a + b; end
      def str_char; a = 'a'; b = char(123); a + b; end
      def str_int; a = 'a'; b = 1; a + b; end
      def str_long; a = 'a'; b = long(1); a + b; end
    ")
    assert_equal("ab", cls.str_str)
    assert_equal("afalse", cls.str_boolean)
    assert_equal("a1.0", cls.str_float)
    assert_equal("a1.0", cls.str_double)
    assert_equal("a1", cls.str_byte)
    assert_equal("a1", cls.str_short)
    assert_equal("a{", cls.str_char)
    assert_equal("a1", cls.str_int)
    assert_equal("a1", cls.str_long)
  end

  def test_string_included
    cls, = compile("def included; 'abcdef'.include? 'd'; end")
    assert cls.included, 'failed to find the contained string'
  end

  def test_string_dont_include
    cls, = compile("def dont_include; 'abcdef'.include? 'g'; end")
    refute cls.dont_include, 'mistakenly found contained string'
  end

  def test_string_include_wrong_type
    assert_raises Mirah::MirahError do
      compile("def include_wrong_type; 'abcdef'.include? 1; end")
    end
  end

  def test_string_match
    cls, = compile(%q{puts 'byeby'.match(/b(.*)y/)[1]})
    assert_run_output("yeb\n", cls)
  end

  def test_string_matches
    cls, = compile("def match; 'abcdef' =~ /d/; end")
    assert cls.match, 'failed to match string'
  end

  def test_string_doesnt_match
    cls, = compile("def doesnt_match; 'abcdef' =~ /g/; end")
    refute cls.doesnt_match, 'mistakenly matched string'
  end

  def test_string_matches_wrong_type
    assert_raises Mirah::MirahError do
      compile("def match_wrong_type; 'abcdef' =~ 'd'; end")
    end
  end
end
