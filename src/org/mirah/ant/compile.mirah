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

package org.mirah.ant

import org.apache.tools.ant.BuildException
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
    @macro_target = nil
    @macro_classpath = nil
    @classpath = Path.new(getProject)
    @dir = '.'
    @bytecode = true
    @verbose = false
    @jvm_version = '1.6'
  end

  def execute:void
    handleOutput("compiling Mirah source in #{expand(@src)} to #{@target}")
    log("classpath: #{@classpath}", 3)
    target = @target
    dir = @dir
    classpath = @classpath.toString
    src = @src
    bytecode = @bytecode
    jvm_version = @jvm_version
    verbose = @verbose
    exception = Exception(nil)

    args = ArrayList.new(
        ['--jvm', jvm_version,
         '-d', target,
         #'--cd', dir,
         '-c', classpath])
    args.add('-V') if verbose
    args.addAll(['--macro-dest', @macro_target]) if @macro_target
    args.addAll(['--macroclasspath', @macro_classpath]) if @macro_classpath
    args.add(src)

    begin
      MirahCommand.compile(args)
    rescue => ex
      raise BuildException.new(exception)
    end
  end

  def setSrc(a:File):void
    @src = a.toString
  end

  def setDestdir(a:File):void
    @target = a.toString
  end

  def setTarget(a:File):void
    @target = a.toString
  end

  def setMacrotarget(a:File):void
    @macro_target = a.toString
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

  def setMacroclasspath(s:Path):void
    createMacroClasspath.append(s)
  end

  def setMacroclasspathref(ref:Reference):void
    createMacroClasspath.setRefid(ref)
  end

  def setBytecode(bytecode:boolean):void
    @bytecode = bytecode
  end

  def setVerbose(verbose:boolean):void
    @verbose = verbose
  end

  def setJvmversion(version:String):void
    @jvm_version = version
  end

  def createClasspath
    @classpath.createPath
  end


  def createMacroClasspath
    @macro_classpath ||= Path.new(getProject)
    @macro_classpath.createPath
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
