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
import org.mirah.MirahClassLoader

class RunCommand < MirahTool
  def initialize
    @class_map = {}
  end

  def consumeClass(filename:String, bytes:byte[]):void
    @class_map[filename] = bytes
  end

  def run
    loader = MirahClassLoader.new(RunCommand.class.getClassLoader, @class_map)
    main_method = nil
    @class_map.keySet.each do |filename:String|
      klass = loader.loadClass(filename)
      params = Class[1]
      params[0] = String[].class
      main_method ||= klass.getMethod("main", params)
    end
    if main_method
      args = Object[1]
      args[0] = String[0]
      main_method.invoke(nil, args)
      0
    else
      puts "No main method found"
      1
    end
  end

  def self.main(args:String[]):void
    mirahc = RunCommand.new()
    result = mirahc.compile(args)
    if result == 0
      result = mirahc.run
    end
    System.exit(result)
  end
end