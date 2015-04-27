# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

class ModifiersTest < Test::Unit::TestCase

  def test_abstract_class
    cls, = compile("abstract class A; end")

    assert_raise do
      cls.new
    end
  end

  def test_abstract_class_inherited
    acls, bcls = compile("abstract class A; end; class B<A;def to_s; 'x';end; end ")
    assert_equal("x","#{bcls.new}")
  end

  def test_final_class_inherited
   cls, = compile("final class A; def to_s; 'x';end; end;")
   assert_equal("x","#{cls.new}")
   assert_raise do
	   compile("final class A; end; class B<A;def to_s; 'x';end; end ")
   end
  end

  def test_new_closure_for_abstract_class
    cls,bcls = compile(%q{
      abstract class A
        abstract def call:String;end
      end
      class B
        def create(a:A):A
          _abstract = 1
          return a
        end

        def create_closure
          create do
            "x"
          end.call
        end
      end
    })
   assert_equal("x","#{bcls.new.create_closure}")
  end
end