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

class StaticFieldsTest < Test::Unit::TestCase
  def test_static_field_inheritance_lookup_with_dot
    cls, = compile(<<-EOF)
      import java.util.GregorianCalendar
      puts GregorianCalendar.AM
    EOF

    assert_run_output("0\n", cls)
  end

  def test_static_field_inheritance_lookup_with_double_colon
    return
    pend("double colon is treated special for lookup") {
    cls, = compile(<<-EOF)
      import java.util.GregorianCalendar
      puts GregorianCalendar::AM
    EOF

    assert_run_output("0\n", cls)
    }
  end

  def test_create_constant
    cls, = compile(<<-EOF)
      CONSTANT = 1
      puts CONSTANT
    EOF
    assert_run_output("1\n", cls)
  end
  
  def test_static_final_constant
    cls, = compile(<<-EOF)
      class Bar
        macro def self.static_final(s:SimpleString,v:Fixnum)
          field_assign = FieldAssign.new(Constant.new(s),v,[Annotation.new(SimpleString.new('org.mirah.jvm.types.Modifiers'), [
            HashEntry.new(SimpleString.new('access'), SimpleString.new('PRIVATE')),
            HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new("STATIC"),SimpleString.new("FINAL")]))
          ])])
          field_assign.isStatic = true
          field_assign.isFinal = true
          field_assign
        end
        
        static_final :serialVersionUID, -1234567890123456789
        
        class << self
          def reflect
            field = Bar.class.getDeclaredField("serialVersionUID")
            puts field.getModifiers
            puts field.get(nil)
          end
        end
      end
      
      Bar.reflect
    EOF
    assert_run_output("26\n-1234567890123456789\n", cls)
  end
end
