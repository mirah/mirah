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

class ImportTest < Test::Unit::TestCase

  def test_quote_import
    cls, = compile("import 'java.util.ArrayList'; def foo; ArrayList.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_no_quote_import
    cls, = compile("import java.util.ArrayList; def foo; ArrayList.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_alias_import_as_syntax
    cls, = compile("import java.util.ArrayList as AL; def foo; AL.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_alias_import_comma_syntax
    cls, = compile("import 'AL', 'java.util.ArrayList'; def foo; AL.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_imported_decl
    cls, = compile("import 'java.util.ArrayList'; def foo(a:ArrayList); a.size; end")
    assert_equal 0, cls.foo(java.util.ArrayList.new)
  end

  def test_import_package_star
    cls, = compile(<<-EOF)
      import java.util.*
      def foo
        ArrayList.new
      end
    EOF
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_static_import_via_include
    cls, = compile(<<-EOF)
      import java.util.Arrays
      include Arrays
      def list(x:Object[])
        asList(x)
      end
    EOF

    o = ["1", "2", "3"].to_java(:object)
    list = cls.list(o)
    assert_kind_of(Java::JavaUtil::List, list)
    assert_equal(["1", "2", "3"], list.to_a)

    cls, = compile(<<-EOF)
      import java.util.Arrays
      class StaticImports
        include Arrays
        def list(x:Object[])
          asList(x)
        end
      end
    EOF

    list = cls.new.list(o)
    assert_kind_of(Java::JavaUtil::List, list)
    assert_equal(["1", "2", "3"], list.to_a)
  end

end
