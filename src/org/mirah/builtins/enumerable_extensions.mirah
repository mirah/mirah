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

class EnumerableExtensions
  macro def all?(block:Block)
    x = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0)
    else
      gensym
    end
    all = gensym
    quote do
      begin
        `all` = true
        `@call.target`.each do |`x`|
          unless (`block.body`)
            `all` = false
            break
          end
        end
        `all`
      end
    end
  end

  macro def all?
    quote do
      `@call.target`.all? {|x| x}
    end
  end

  macro def any?(block:Block)
    x = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0)
    else
      gensym
    end
    any = gensym
    quote do
      begin
        `any` = false
        `@call.target`.each do |`x`|
          if (`block.body`)
            `any` = true
            break
          end
        end
        `any`
      end
    end
  end

  macro def any?
    quote do
      `@call.target`.any? {|x| x}
    end
  end
end
