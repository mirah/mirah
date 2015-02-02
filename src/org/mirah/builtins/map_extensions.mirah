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

package org.mirah.builtins

class MapExtensions
  macro def [](key)
    quote { `@call.target`.get(`key`) }
  end

  macro def []=(key, value)
    wrapped_value = [value]
    quote { `@call.target`.put(`key`, `wrapped_value`) }
  end

  macro def empty?
    quote { `@call.target`.isEmpty }
  end

  macro def keys
    quote { `@call.target`.keySet }
  end

  # TODO each
end
