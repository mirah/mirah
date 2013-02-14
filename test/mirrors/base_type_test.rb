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

class BaseTypeTest < Test::Unit::TestCase
  java_import 'org.jruby.org.objectweb.asm.Type'
  java_import 'org.jruby.org.objectweb.asm.Opcodes'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.Member'
  java_import 'org.mirah.jvm.types.MemberKind'
  def setup
    @type = BaseType.new(Type.getType("LFooBar;"), 0, nil)
    @void = BaseType.new(Type.getType("V"), 0, nil)
  end
  
  def test_tostring
    assert_equal("FooBar", @type.toString)
  end
  
  def test_getmethod
    constructor = Member.new(Opcodes.ACC_PUBLIC, @type, "<init>", [], @void, MemberKind::CONSTRUCTOR)
    copy = Member.new(Opcodes.ACC_PUBLIC, @type, "copyFrom", [@type], @void, MemberKind::METHOD)
    @type.add(constructor)
    @type.add(copy)
    assert_nil(@type.getMethod('foobar', []))
    assert_equal(constructor, @type.getMethod('<init>', []))
    assert_nil(@type.getMethod('<init>', [@type]))
    assert_equal(copy, @type.getMethod('copyFrom', [@type]))
    assert_nil(@type.getMethod('copyFrom', []))
  end
end