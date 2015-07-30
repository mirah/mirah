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
    'macros/string_each_char' => "l\na\na\nt\n \nd\ne\n \nl\ne\ne\ne\nu\nw\n \nn\ni\ne\nt\n \ni\nn\n \nz\ni\nj\nn\n \nh\ne\nm\np\ni\ne\n \ns\nt\na\na\nn\n",
    'sort_closure' =>
      "unsorted: [9, 5, 2, 6, 8, 5, 0, 3, 6, 1, 8, 3, 6, 4, 7, 5, 0, 8, 5, 6, 7, 2, 3]\n" +
      "sorted:   [0, 0, 1, 2, 2, 3, 3, 3, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 8, 8, 8, 9]\n",
    'rosettacode/fizz-buzz' => "1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n16\n17\nFizz\n19\nBuzz\nFizz\n22\n23\nFizz\nBuzz\n26\nFizz\n28\n29\nFizzBuzz\n31\n32\nFizz\n34\nBuzz\nFizz\n37\n38\nFizz\nBuzz\n41\nFizz\n43\n44\nFizzBuzz\n46\n47\nFizz\n49\nBuzz\nFizz\n52\n53\nFizz\nBuzz\n56\nFizz\n58\n59\nFizzBuzz\n61\n62\nFizz\n64\nBuzz\nFizz\n67\n68\nFizz\nBuzz\n71\nFizz\n73\n74\nFizzBuzz\n76\n77\nFizz\n79\nBuzz\nFizz\n82\n83\nFizz\nBuzz\n86\nFizz\n88\n89\nFizzBuzz\n91\n92\nFizz\n94\nBuzz\nFizz\n97\n98\nFizz\nBuzz\n1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n16\n17\nFizz\n19\nBuzz\nFizz\n22\n23\nFizz\nBuzz\n26\nFizz\n28\n29\nFizzBuzz\n31\n32\nFizz\n34\nBuzz\nFizz\n37\n38\nFizz\nBuzz\n41\nFizz\n43\n44\nFizzBuzz\n46\n47\nFizz\n49\nBuzz\nFizz\n52\n53\nFizz\nBuzz\n56\nFizz\n58\n59\nFizzBuzz\n61\n62\nFizz\n64\nBuzz\nFizz\n67\n68\nFizz\nBuzz\n71\nFizz\n73\n74\nFizzBuzz\n76\n77\nFizz\n79\nBuzz\nFizz\n82\n83\nFizz\nBuzz\n86\nFizz\n88\n89\nFizzBuzz\n91\n92\nFizz\n94\nBuzz\nFizz\n97\n98\nFizz\nBuzz\n",
  }.each do |example,output|
    define_method "test_#{example}" do
      example_test example, output
    end
  end
end
