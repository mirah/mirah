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

class TestBlocks < Test::Unit::TestCase

  def setup
    super
    clear_tmp_files
    reset_type_factory
  end
  
  def parse_and_type code, name=tmp_script_name
    parse_and_resolve_types name, code
  end
  
  #this should probably be a core test
  def test_empty_block_parses_and_types_without_error
    assert_nothing_raised do
      parse_and_type(<<-CODE)
        interface Bar do;def run:void;end;end
      
        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
        end
      CODE
    end
  end
  
  def test_non_empty_block_parses_and_types_without_error
    assert_nothing_raised do
      parse_and_type(<<-CODE)
        interface Bar do;def run:void;end;end
      
        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
          1
        end
      CODE
    end
  end


  def test_block_impling_interface_w_multiple_methods
    assert_raises Mirah::NodeError do
      parse_and_type(<<-CODE)
        interface Bar do
          def run:void;end
          def run2:void;end;
        end
        
        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
          1
        end
        CODE
    end
  end

  def test_block_with_no_params_on_interface_with
    assert_raises Mirah::NodeError do
      parse_and_type(<<-CODE)
        interface Bar do
          def run(a:string):void;end
        end
        
        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
          1
        end
        CODE
      end
  end

  def test_block_with_too_many_params
    assert_raises Mirah::NodeError do
      parse_and_type(<<-CODE)
        interface Bar do
          def run(a:string):void;end
        end
        
        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do |a, b|
          1
        end
        CODE
      end
  end

end
