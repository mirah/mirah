# Copyright (c) 2010-2013 The Mirah project authors. All Rights Reserved.
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

class ClosureTest < Test::Unit::TestCase

  def test_interface_defined_after_used
    cls, = compile(%q{
      class FooTest1
        def self.main(argv:String[]):void
          FooB.new.action do
            puts "executed foo1"
          end
        end
      end
      
      class FooB
        def action(foo_param:Foo_Interface):void
          foo_param.anymethod
        end
      end 
      
      interface Foo_Interface
        def anymethod():void; end
      end
      
      class FooTest2
        def self.main(argv:String[]):void
          FooB.new.action do
            puts "executed foo2"
          end
        end
      end
      FooTest2.main(String[0])
      FooTest1.main(String[0])
    })
    assert_run_output("executed foo2\nexecuted foo1\n", cls)
  end
  
  def test_super_is_not_synthesized_when_not_necessary
    cls, = compile(%q{
      class Bar
        def initialize(val:int)
          puts "bar"
        end
      end
      
      class Foo < Bar
        attr_accessor baz:String
        
        def initialize(val:int)
          super
          foo = 5
          puts "foo"
          perform do
            puts foo
          end
        end
        
        def perform(runnable:Runnable)
          runnable.run
        end
      end
      Foo.new(3)
    })
    assert_run_output("bar\nfoo\n5\n", cls)
  end
end
