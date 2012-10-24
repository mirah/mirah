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

import org.mirah.macros.anno.*
import org.mirah.macros.Macro
import org.mirah.macros.Compiler
import mirah.lang.ast.*

$MacroDef[name: `name`, arguments:`argdef`]
class `classname` implements Macro
  def initialize(mirah:Compiler, call:CallSite)
    @mirah = mirah
    @call = call
  end

  def _expand(`args`):Node
    `body`
  end

  def expand:Node
    _expand(`casts`)
  end

  def gensym:String
    @mirah.scoper.getScope(@call).temp('gensym')
  end
end
