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

import org.mirah.util.Logger
import org.objectweb.asm.Opcodes
import org.objectweb.asm.ClassWriter

class JvmVersion
  def self.initialize:void
    @@log = Logger.getLogger(JvmVersion.class.getName)
  end

  def initialize
    initialize(System.getProperty('java.specification.version'))
  end

  def initialize(version:String)
    @version_string = version
    @version = if "1.4".equals(version)
      Opcodes.V1_4
    elsif "1.5".equals(version)
      Opcodes.V1_5
    elsif "1.6".equals(version)
      Opcodes.V1_6
    elsif "1.7".equals(version)
      Opcodes.V1_7
    elsif "1.8".equals(version)
      Opcodes.V1_8
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

  def bytecode_version
    @version
  end

  def supports_default_interface_methods
    @version >= Opcodes.V1_8
  end

  attr_reader flags:int, version:int, version_string:String
end