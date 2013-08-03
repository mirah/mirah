# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
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

package org.mirah.typer

import mirah.lang.ast.Block

class BlockFuture < BaseTypeFuture
  def initialize(block:Block, listener:TypeListener)
    super(block.position)
    @block = block
    @basic_block_method_type = MethodType(nil)
    onUpdate(listener)
  end

  def block
    @block
  end

  def basic_block_method_type= type: MethodType
    @basic_block_method_type = type
  end


  def basic_block_method_type: MethodType
    @basic_block_method_type
  end
end
