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

package org.mirah.jvm.compiler

import org.mirah.util.Context
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.MirrorType
import org.objectweb.asm.ClassWriter

class MirahClassWriter < ClassWriter
  def initialize(context:Context, flags:int)
    super(flags)
    @types = context[MirrorTypeSystem]
  end
  def getCommonSuperClass(a, b)
    if @types
      resolved_a = MirrorType(@types.loadNamedType(a).resolve)
      resolved_b = MirrorType(@types.loadNamedType(b).resolve)
      wide = MirrorType(resolved_a.widen(resolved_b)).erasure
      MirrorType(wide).getAsmType.getInternalName
    else
      super
    end
  end
end