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

import mirah.lang.ast.*
import org.mirah.util.Context

# Runs class cleanup on any enclosed classes.
class MethodCleanup < NodeScanner
  def initialize(context:Context, method:MethodDefinition)
    @context = context
    @method = method
  end

  def clean:void
    scan(@method.body, nil)
  end

  def enterDefault(node, arg)
    false
  end

  def enterClassDefinition(node, arg)
    ClassCleanup.new(@context, node).clean
    false
  end

  def enterClosureDefinition(node, arg)
    enterClassDefinition(node, arg)
    false
  end

  def enterInterfaceDeclaration(node, arg)
    enterClassDefinition(node, arg)
    false
  end

  def enterNodeList(node, arg)
    # Scan the children
    true
  end
end
