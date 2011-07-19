# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
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

import org.apache.tools.ant.Task
import org.apache.tools.ant.types.Path
import org.apache.tools.ant.types.Reference

import org.mirah.MirahCommand

import java.io.File
import java.util.ArrayList

class Compile < Task
  def initialize
    @src = '.'
    @target = '.'
    @classpath = Path.new(getProject)
    @dir = '.'
    @bytecode = true
    @verbose = false
  end

  def execute:void
    
    handleOutput("compiling Mirah source in #{expand(@src)} to #{@target}")
    log("classpath: #{@classpath}", 3)
    # JRuby wants to use the context classloader, but that's ant's
    # classloader, not the one that contains JRuby.
    target = @target
    dir = @dir
    classpath = @classpath.toString
    src = @src
    bytecode = @bytecode
    verbose = @verbose
    exception = Exception(nil)

    t = Thread.new do
      Thread.currentThread.setContextClassLoader(Compile.class.getClassLoader())
      args = ArrayList.new(
          ['-d', target, '--cd', dir, '-c', classpath, src])
      args.add(0, '--java') unless bytecode
      args.add(0, '-V') if verbose

      begin
        MirahCommand.compile(args)
      rescue => ex
        exception = ex
      end
    end
    t.start
    t.join
    raise exception if exception
  end

  def setSrc(a:File):void
    @src = a.toString
  end

  def setDestdir(a:File):void
    @target = a.toString
  end

  def setDir(a:File):void
    @dir = a.toString
  end

  def setClasspath(s:Path):void
    createClasspath.append(s)
  end

  def setClasspathref(ref:Reference):void
    createClasspath.setRefid(ref)
  end

  def setBytecode(bytecode:boolean):void
    @bytecode = bytecode
  end

  def setVerbose(verbose:boolean):void
    @verbose = verbose
  end

  def createClasspath
    @classpath.createPath
  end

  def expand(path:String)
    file = File.new(path)
    if file.isAbsolute || @dir.nil?
      path
    else
      File.new(@dir, path).toString
    end
  end
end
