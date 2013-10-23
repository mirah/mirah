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

class StringBuilderExtensionsTest < Test::Unit::TestCase
  def test_string_builder_greetings
    result = '<p>Greetings are: hello hola ciao salut hallo</p>'
    cls, = compile(<<-EOF)
    def greetings
      languages = ['hello ', 'hola ', 'ciao ', 'salut ', 'hallo']
      greetings = StringBuilder.new
      greetings << '<p>Greetings are: '
      languages.each { |greet| greetings << greet }
      greetings << '</p>'
      greetings.toString
    end
    EOF
    assert_equal result, cls.greetings
  end

  def test_string_builder_shovel_object
    cls, = compile(<<-EOF)
    class MyObject
      def toString
        "Hey, I am a shiny instance of \#{getClass.getName}"
      end
    end

    def shovel_object
      sb = StringBuilder.new
      sb << MyObject.new
      sb.toString
    end
    EOF
    result = 'Hey, I am a shiny instance of MyObject'
    assert_equal result, cls.shovel_object
  end
end
