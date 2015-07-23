# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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


package org.mirah.jvm.compiler

import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import java.net.URLClassLoader
import java.util.HashSet
import java.util.List

import org.mirah.util.Logger
import java.util.logging.Level

import java.util.Collections
import java.util.Map
import java.util.HashMap

import mirah.lang.ast.Package as MirahPackage
import mirah.lang.ast.*
import org.mirah.jvm.compiler.Backend
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.BetterScopeFactory
import org.mirah.jvm.mirrors.MirrorScope
import org.mirah.jvm.mirrors.ClassResourceLoader
import org.mirah.jvm.mirrors.ClassLoaderResourceLoader
import org.mirah.jvm.mirrors.FilteredResources
import org.mirah.jvm.mirrors.NegativeFilteredResources

import org.mirah.typer.Typer
import org.mirah.typer.TypeSystem
import org.mirah.util.Context

class ExtensionCleanup < NodeScanner
  def self.initialize:void
    @@log = Logger.getLogger(ExtensionCleanup.class.getName)
  end

  def initialize(macro_backend: Backend,
                 extension_classes: Map,
                 macro_destination: String,
                 macro_typer: Typer)
    @macro_backend = macro_backend
    @extension_classes = extension_classes
    @macro_destination = macro_destination
    @macro_typer = macro_typer
  end

  def enterPackage(pac, map)
    # we need the package to ensure that the $Extensions class is put in the right package
    Map(map)[:package]= pac.name.identifier
    true
  end

  def enterClassDefinition(classdef, map)
    classdef.annotations_size.times do |i|
      anno = classdef.annotations(i)
      if anno.type.typeref.name.equals('org.mirah.macros.anno.Extensions')
        extensions_anno = anno
        break
      end
    end
    return false unless extensions_anno
    pos = classdef.position
    classdef.annotations.removeChild(extensions_anno)

    class_name = Constant.new(pos,
      SimpleString.new(pos, "#{classdef.name.identifier}$Extensions"))
    new_klass = ClassDefinition.new(pos,
      class_name,
      nil,
      Collections.emptyList, # body
      Collections.emptyList, # interfaces
      [extensions_anno]
       )
    pkg_str = String(Map(map).get(:package))
    pkg_name = Unquote.new(pos, SimpleString.new(pkg_str))
    new_pkg = MirahPackage.new(pos, pkg_name, nil)
    script = Script.new(pos, [new_pkg, new_klass])

    @macro_typer.infer(script, false)
    @macro_backend.clean(script, nil)
    @macro_backend.compile(script, nil)

    class_name_written = Backend.write_out_file(
      @macro_backend, @extension_classes, @macro_destination)
    @@log.fine "extensions file compiled #{class_name_written}"
    true
  end
end

