# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

package org.mirah

import java.util.Arrays
import java.util.List
import org.mirah.tool.Mirahc
import org.mirah.tool.RunCommand

class MirahCommand
  def self.compile(args:List): int
    argv = String[args.size]
    args.toArray(argv)
    Mirahc.new.compile(argv)
  end

  def self.run(args:List): int
    argv = String[args.size]
    args.toArray(argv)
    RunCommand.run(argv)
  end

  def self.main(args:String[]):void
    list = Arrays.asList(args)
    if list.size > 0 && "run".equals(list.get(0))
      result = run(list.subList(1, list.size))
      # NB only exit from a run if it failed.
      System.exit(result) unless result == 0
    elsif list.size > 0 && "compile".equals(list.get(0))
      System.exit(compile(list.subList(1, list.size)))
    else
      System.exit(compile(list))
    end
  end
end
