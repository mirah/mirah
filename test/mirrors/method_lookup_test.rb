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

class MethodLookupTest < Test::Unit::TestCase
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.mirrors.MethodLookup'
  java_import 'org.mirah.typer.simple.SimpleScope'
  java_import 'org.mirah.typer.ErrorType'
  java_import 'org.jruby.org.objectweb.asm.Type'

  def setup
    @types = MirrorTypeSystem.new
    @scope = SimpleScope.new
  end

  def test_object_supertype
    main_future = @types.getMainType(nil, nil)
    object = @types.getSuperClass(main_future).resolve
    main = main_future.resolve
    assert(MethodLookup.isSubType(main, main))
    assert(MethodLookup.isSubType(main, object))
    assert_false(MethodLookup.isSubType(object, main))
    error = ErrorType.new([['Error']])
    assert(MethodLookup.isSubType(error, main))
    assert(MethodLookup.isSubType(main, error))
  end
  
  # TODO interfaces
  
  def wrap(descriptor)
    @types.wrap(Type.getType(descriptor)).resolve
  end
  
  def check_supertypes(type, *supertypes)
    supertypes.each do |supertype|
      assert_block("Expected #{type} < #{supertype}") do
        MethodLookup.isSubType(type, supertype)
      end
    end
  end
  
  def check_not_supertypes(type, *supertypes)
    supertypes.each do |supertype|
      assert_block("Expected !(#{type} < #{supertype})") do
        !MethodLookup.isSubType(type, supertype)
      end
    end
  end
  
  def test_primitive_supertypes
    double = wrap('D')
    float = wrap('F')
    long = wrap('J')
    int = wrap('I')
    short = wrap('S')
    char = wrap('C')
    byte = wrap('B')
    bool = wrap('Z')
    check_supertypes(double, double)
    check_not_supertypes(double, float, long, int, short, char, byte, bool)
    check_supertypes(float, double, float)
    check_not_supertypes(float, long, int, short, char, byte, bool)
    check_supertypes(long, double, float, long)
    check_not_supertypes(long, int, short, char, byte, bool)
    check_supertypes(int, double, float, long, int)
    check_not_supertypes(int, short, char, byte, bool)
    check_supertypes(short, double, float, long, int, short)
    check_not_supertypes(short, char, byte, bool)
    check_supertypes(char, double, float, long, int, char)
    check_not_supertypes(char, byte, bool)
    check_supertypes(byte, double, float, long, int, short)
    check_not_supertypes(byte, char, bool)
    check_supertypes(bool, bool)
    check_not_supertypes(bool, double, float, long, int, short, char, byte)
  end
end