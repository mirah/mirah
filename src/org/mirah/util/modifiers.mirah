# Copyright (c) 2016 The Mirah project authors. All Rights Reserved.
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
package org.mirah.util

import org.objectweb.asm.Opcodes

# Holds a static list of the modifiers supported through Mirah's compile time annotations. 
#
class MirahModifiers
  def self.initialize
	  @@ACCESS = {
      PUBLIC: Opcodes.ACC_PUBLIC,
      PRIVATE: Opcodes.ACC_PRIVATE,
      PROTECTED: Opcodes.ACC_PROTECTED,
      DEFAULT: 0
    }
    @@FLAGS = {
      STATIC: Opcodes.ACC_STATIC,
      FINAL: Opcodes.ACC_FINAL,
      SUPER: Opcodes.ACC_SUPER,
      SYNCHRONIZED: Opcodes.ACC_SYNCHRONIZED,
      VOLATILE: Opcodes.ACC_VOLATILE,
      BRIDGE: Opcodes.ACC_BRIDGE,
      VARARGS: Opcodes.ACC_VARARGS,
      TRANSIENT: Opcodes.ACC_TRANSIENT,
      NATIVE: Opcodes.ACC_NATIVE,
      INTERFACE: Opcodes.ACC_INTERFACE,
      ABSTRACT: Opcodes.ACC_ABSTRACT,
      STRICT: Opcodes.ACC_STRICT,
      SYNTHETIC: Opcodes.ACC_SYNTHETIC,
      ANNOTATION: Opcodes.ACC_ANNOTATION,
      ENUM: Opcodes.ACC_ENUM,
      DEPRECATED: Opcodes.ACC_DEPRECATED
    }
  end

  # TODO switch from these to MirahModifiers::ACCESS et al when the better constant lookup handling happens
  def self.access_modifiers
    @@ACCESS
  end

  def self.flag_modifiers
    @@FLAGS
  end
end