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

package org.mirah.tool

import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream

class Mirahc < MirahTool

  def consumeClass(filename:String, bytes:byte[]):void
    file = File.new(destination, "#{filename.replace(?., ?/)}.class")
    parent = file.getParentFile
    parent.mkdirs if parent
    output = BufferedOutputStream.new(FileOutputStream.new(file))
    output.write(bytes)
    output.close
  end

  def self.main(args:String[]):void
    result = Mirahc.new.compile(args)
    System.exit(result)
  end
end