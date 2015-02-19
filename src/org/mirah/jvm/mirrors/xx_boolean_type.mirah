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

package org.mirah.jvm.mirrors

import org.objectweb.asm.Type
import org.mirah.util.Context

class BooleanType < Number
  def initialize(context:Context, loader:MirrorLoader)
    super(context, Type.getType('Z'), nil, loader)
  end

  def load_methods
    # TODO non-coercive
    add_comparison('===', self, self)
    add_comparison('!==', self, self)
    add_comparison('==', self, self)
    add_comparison('!=', self, self)
    add_math("|", self)
    add_math("&", self)
    add_math("^", self)
    true
  end
end