# Copyright (c) 2013-2014 The Mirah project authors. All Rights Reserved.
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

import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set

import mirah.lang.ast.Position
import org.mirah.typer.LocalFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scope
import org.mirah.typer.Scoper
import org.mirah.typer.TypeFuture


# additional extensions on the base scope interface used by the
# mirror typesystem
interface MirrorScope < Scope

  # scope of the AST outside the current node. It may not be the parent scope.
  def outer_scope: MirrorScope; end
  # Currently available static imports
  def staticImports: Set; end
  # the fetch methods are internal bookkeeping for recursively looking up
  # available imports / packages
  def fetch_imports(something: Map): Map; end
  def fetch_static_imports(something: Set): Set; end
  def fetch_packages(list: List): List; end
end