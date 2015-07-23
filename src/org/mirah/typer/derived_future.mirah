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

package org.mirah.typer

import java.util.*
import org.mirah.util.Logger
import java.util.logging.Level
import mirah.lang.ast.*

interface ResolvedTypeTransformer do
  def transform(type:ResolvedType):ResolvedType; end
end

# Future for a type derived from another.
# Resolves to the target if the target is an error.
# Otherwise, resolves to the transformation of that type.
class DerivedFuture < BaseTypeFuture
  def initialize(target:TypeFuture, transformer:ResolvedTypeTransformer)
    if target.kind_of?(BaseTypeFuture)
      self.position = BaseTypeFuture(target).position
    end
    @target = target
    @transformer = transformer
    future = self
    target.onUpdate do |x, resolved|
      if resolved.isError
        future.resolved(resolved)
      else
        future.resolved(transformer.transform(resolved))
      end
    end
  end

  def resolve()
    unless isResolved
      @target.resolve
    end
    super
  end
  
  def peekInferredType
    @transformer.transform(@target.peekInferredType)
  end

  def dump(out)
    out.write("target: ")
    out.printFuture(@target)
    super
  end

  def getComponents
    {target: @target}
  end
end
