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

import java.util.Collections
import org.mirah.util.Logger
import javax.tools.DiagnosticListener
import mirah.lang.ast.*
import org.mirah.typer.Typer
import org.mirah.macros.Compiler as MacroCompiler
import org.mirah.util.Context
import org.mirah.util.MirahDiagnostic

import java.util.ArrayList

# Helper for annotating fields in ClassCleanup: Finds and removes
# annotations on FieldAssignments. ClassCleanup will generate
# FieldDeclarations containing the annotations.
class AnnotationCollector < NodeScanner
  def initialize(context:Context)
    @context = context
    @field_annotations = {}
  end

  def error(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.error(position, message))
  end

  def collect(node:Node):void
    scan(node, nil)
  end

  def getAnnotations(field:String):AnnotationList
    AnnotationList(@field_annotations[field])
  end
  
  def enterFieldAssign(node, arg)
    name = node.name.identifier
    if node.annotations && node.annotations_size > 0
      if @field_annotations[name]
        error("Multiple declarations for field #{name}", node.position)
      else
        @field_annotations[name] = node.annotations
        node.annotations = AnnotationList.new()
      end
    end
    false
  end
  
  def enterNodeList(node, arg)
    # Scan the children
    true
  end

  def enterRescue(node, arg)
    true
  end

  def enterDefault(node, arg)
    # We only treat it as a declaration if it's at the top level
    false
  end
end