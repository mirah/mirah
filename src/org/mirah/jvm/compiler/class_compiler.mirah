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

package org.mirah.jvm.compiler

import java.io.File
import java.util.logging.Logger
import mirah.lang.ast.ClassDefinition
import org.mirah.util.Context

import org.jruby.org.objectweb.asm.ClassWriter
import org.jruby.org.objectweb.asm.Opcodes

class ClassCompiler < BaseCompiler
  def self.initialize:void
    @@log = Logger.getLogger(ClassCompiler.class.getName)
  end
  def initialize(context:Context, classdef:ClassDefinition)
    super(context)
    @classdef = classdef
  end
  
  def compile:void
    @@log.info "Compiling class #{@classdef.name.identifier}"
    @type = getInferredType(@classdef)
    startClass
    @classwriter.visitEnd
  end
  
  def getBytes:byte[]
    # TODO CheckClassAdapter
    @classwriter.toByteArray
  end
  
  def startClass:void
    # TODO: need to support widening before we use COMPUTE_FRAMES
    @classwriter = ClassWriter.new(ClassWriter.COMPUTE_MAXS)
    @classwriter.visit(Opcodes.V1_6, flags, internal_name, nil, superclass, interfaces)
    filename = self.filename
    @classwriter.visitSource(filename, nil) if filename
    context[AnnotationCompiler].compile(@classdef.annotations, @classwriter)
  end
  
  def flags
    Opcodes.ACC_PUBLIC | Opcodes.ACC_SUPER
  end
  
  def internal_name
    @type.internal_name
  end
  
  def filename
    if @classdef.position
      path = @classdef.position.source.name
      lastslash = path.lastIndexOf(File.separatorChar)
      if lastslash == -1
        return path
      else
        return path.substring(lastslash + 1)
      end
    end
    nil
  end
  
  def superclass
    getInferredType(@classdef.superclass).internal_name if @classdef.superclass
  end
  
  def interfaces
    size = @classdef.interfaces.size
    array = String[size]
    i = 0
    size.times do |i|
      node = @classdef.interfaces.get(i)
      array[i] = getInferredType(node).internal_name
      i += 1
    end
    array
  end
end