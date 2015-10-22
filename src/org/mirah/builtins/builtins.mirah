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

package org.mirah.builtins

import org.mirah.typer.TypeSystem
import java.util.Collections
import org.mirah.macros.ExtensionsProvider
import org.mirah.macros.ExtensionsService

class Builtins implements ExtensionsProvider

  def register(type_system:ExtensionsService):void
    type_system.macro_registration(ArrayExtensions.class)
    type_system.macro_registration(CollectionExtensions.class)
    type_system.macro_registration(MapExtensions.class)
    type_system.macro_registration(ListExtensions.class)
    type_system.macro_registration(ObjectExtensions.class)
    type_system.macro_registration(EnumerableExtensions.class)
    type_system.macro_registration(IterableExtensions.class)
    type_system.macro_registration(StringExtensions.class)
    type_system.macro_registration(StringBuilderExtensions.class)
    type_system.macro_registration(LockExtensions.class)
    type_system.macro_registration(IntExtensions.class)
    type_system.macro_registration(NumberExtensions.class)
    type_system.macro_registration(MatcherExtensions.class)
    type_system.macro_registration(IntegerOperators.class)
    type_system.macro_registration(ByteOperators.class)
    type_system.macro_registration(ShortOperators.class)
    type_system.macro_registration(LongOperators.class)
    type_system.macro_registration(DoubleOperators.class)
    type_system.macro_registration(FloatOperators.class)
  end

end
