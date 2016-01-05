# Copyright (c) 2012-2015 The Mirah project authors. All Rights Reserved.
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

package org.mirah.typer.closures

import mirah.lang.ast.*
import org.mirah.typer.TypeFuture
import org.mirah.typer.ResolvedType

interface ClosureBuilderer
  def insert_closure(block: Block, parent_type: ResolvedType): TypeFuture; end
  def add_todo(block: Block, parent_type: ResolvedType): void; end
  def finish: void; end
end