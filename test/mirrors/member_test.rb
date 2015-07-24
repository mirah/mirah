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
require 'java'
require ENV.fetch('MIRAHC_JAR',File.expand_path("../../../dist/mirahc.jar",__FILE__))

class MembersTest < Test::Unit::TestCase
  java_import 'org.mirah.jvm.mirrors.Member'
  java_import 'org.mirah.jvm.types.JVMType'
  java_import 'org.mirah.jvm.types.MemberKind'

  class Visitor
    def method_missing(name, *args)
      @visited = name
    end
    attr_reader :visited
  end
  
  class FakeType
    include JVMType
  end

  def create_member(kind)
    @flags = kind.name.hash
    @name = "foo#{kind}"
    @klass = FakeType.new
    @args = [FakeType.new]
    @return_type = FakeType.new
    Member.new(@flags, @klass, @name, @args, @return_type, kind)
  end

  def check_fields(member, kind)
    assert_equal(@flags, member.flags)
    assert_equal(@name, member.name)
    assert_equal(@klass, member.declaringClass)
    assert_equal(@args, member.argumentTypes.to_a)
    assert_equal(@return_type, member.returnType)
    assert_equal(kind, member.kind)
  end

  def check_visitor(member, kind)
    visitor = Visitor.new
    member.accept(visitor, false)
    assert_match(/^#{visitor.visited}/i, "visit#{kind.name.gsub('_','')}call")
  end

  MemberKind.constants.each do |name|
    eval(<<-EOF)
      def test_#{name}
        kind = MemberKind.const_get(:#{name})
        member = create_member(kind)
        check_fields(member, kind)
        check_visitor(member, kind)
      end
    EOF
  end
end