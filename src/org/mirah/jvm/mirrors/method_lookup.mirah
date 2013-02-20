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

package org.mirah.jvm.mirrors

import java.util.HashSet
import java.util.LinkedList
import org.mirah.typer.ResolvedType
import org.mirah.jvm.types.JVMType

class MethodLookup
  class << self
    def isSubType(subtype:ResolvedType, supertype:ResolvedType):boolean
      return true if subtype == supertype
      if subtype.kind_of?(JVMType) && supertype.kind_of?(JVMType)
        return isJvmSubType(JVMType(subtype), JVMType(supertype))
      end
      return true if subtype.matchesAnything
      return supertype.matchesAnything
    end
  
    def isJvmSubType(subtype:JVMType, supertype:JVMType):boolean
      if subtype.isPrimitive
        return supertype.isPrimitive && isPrimitiveSubType(subtype, supertype)
      end
      super_desc = supertype.class_id
      explored = HashSet.new
      to_explore = LinkedList.new
      to_explore.add(subtype)
      until to_explore.isEmpty
        next_type = to_explore.removeFirst
        descriptor = next_type.class_id
        return true if descriptor.equals(super_desc)
        unless explored.contains(descriptor)
          explored.add(descriptor)
          to_explore.add(next_type.superclass) if next_type.superclass
          next_type.interfaces.each {|i| to_explore.add(JVMType(i.resolve))}
        end
      end
      return false
    end
  
    def isPrimitiveSubType(subtype:JVMType, supertype:JVMType):boolean
      sub_desc = subtype.class_id.charAt(0)
      super_desc = supertype.class_id.charAt(0)
      order = "BSIJFD"
      if sub_desc == super_desc
        return true
      elsif sub_desc == ?Z
        return false
      elsif sub_desc == ?C
        return order.indexOf(super_desc) > 1
      else
        return order.indexOf(super_desc) >= order.indexOf(sub_desc)
      end
    end
  end
end