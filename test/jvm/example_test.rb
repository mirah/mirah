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

# these are here to make sure the examples still run.
#
class ExampleTest < Test::Unit::TestCase
  def compile_ex name
    filename = File.dirname(__FILE__) + "/../../examples/#{name}.mirah"
    compile(open(filename).read).first
  end

  def example_test name, output
    cls = compile_ex name
    assert_run_output(output, cls)
  end

  {
    'simple_class' => "constructor\nHello, \nMirah\n",
    'macros/square' => "2.0\n8.0\n",
    'macros/square_int' => "2.0\n8.0\n",
    'macros/string_each_char' => "l\na\na\nt\n \nd\ne\n \nl\ne\ne\ne\nu\nw\n \nn\ni\ne\nt\n \ni\nn\n \nz\ni\nj\nn\n \nh\ne\nm\np\ni\ne\n \ns\nt\na\na\nn\n"
  }.each do |example,output|
    define_method "test_#{example}" do
      example_test example, output
    end
  end
end
