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

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.ClassWriter

class JvmVersion
  def initialize
    initialize(System.getProperty('java.specification.version'))
  end

  def initialize(version:String)
    @version = if "1.4".equals(version)
      Opcodes.V1_4
    elsif "1.5".equals(version)
      Opcodes.V1_5
    elsif "1.6".equals(version)
      Opcodes.V1_6
    elsif "1.7".equals(version)
      Opcodes.V1_7
    else
      -1
    end
    if @version < 0
      raise IllegalArgumentException, "Unsupported jvm version #{version}"
    end
    @flags = ClassWriter.COMPUTE_MAXS
    if @version > Opcodes.V1_5
      @flags |= ClassWriter.COMPUTE_FRAMES
    end
  end

  attr_reader flags:int, version:int
end