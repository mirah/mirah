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
require 'test_helper'

class TypeFutureTest < Test::Unit::TestCase
  include Mirah
  include Mirah::Util::ProcessErrors
  java_import 'org.mirah.typer.TypeFuture'
  java_import 'org.mirah.typer.AssignableTypeFuture'
  java_import 'org.mirah.typer.SimpleFuture'
  java_import 'org.mirah.typer.simple.SimpleTypes'
  java_import 'org.mirah.typer.simple.SimpleType'
  java_import 'org.mirah.typer.ErrorType'
  java_import 'mirah.lang.ast.VCall'
  java_import 'mirah.lang.ast.FunctionalCall'
  java_import 'mirah.lang.ast.PositionImpl'
  java_import 'mirah.lang.ast.LocalAccess'

  module TypeFuture
    def inspect
      toString
    end
  end
  
  POS = PositionImpl.new(nil, 0, 0, 0, 0, 0, 0)

# error type test

# END error type test

  def test_assignable_future_when_declared_resolves_to_declared_type
    future = AssignableTypeFuture.new POS
    type = SimpleType.new("Object",false,false)
    future.declare SimpleFuture.new(type), POS

    assert_equal type, future.resolve, "Expected #{future.resolve} to be a #{type}"
  end


  def test_assignable_future_doesnt_allow_multiple_declarations_of_different_types
    future = AssignableTypeFuture.new POS
    future.declare SimpleFuture.new(SimpleType.new("Object",false,false)), POS
    future.declare SimpleFuture.new(SimpleType.new("NotObject",false,false)), POS

    assign_future = future.assign SimpleFuture.new(SimpleType.new("Object",false,false)), POS

    assert_kind_of ErrorType, assign_future.resolve
  end

  def test_assignable_future_doesnt_allow_invalid_assignment_to_declared_type
    future = AssignableTypeFuture.new POS
    f = SimpleFuture.new(SimpleType.new("Object",false,false))

    future.declare f, POS
    
    assignment_future = future.assign SimpleFuture.new(SimpleType.new("NotObject",false,false)), POS
    
    assert_kind_of ErrorType, assignment_future.resolve
  end
end