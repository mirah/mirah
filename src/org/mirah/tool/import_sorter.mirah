# Copyright (c) 2014 The Mirah project authors. All Rights Reserved.
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

import java.util.Collections
import java.util.List
import org.mirah.util.Logger
import mirah.lang.ast.*

# this didn't work
# for a proper sort, we need to a proper graph sort:
#   http://en.wikipedia.org/wiki/Topological_sorting
# first, turn the list of scripts into a graph
# then do a topo sort on the graph
# easier said then done though.


# Sorts lists of AST nodes roughly by package / imports
# if file's package are ==, have same val
# if file has import for other file, other file is less than
# if other file has import for file, file is greater than
class ImportSorter < NodeScanner
  def self.initialize
    @@log = Logger.getLogger(ImportSorter.class.getName)
  end

  def self.log
    @@log
  end

  def sort(asts: List): List
    infos = asts.map do |ast: Node|
      info = FileInfo.new(ast)
      ast.accept self, info
      info
    end
    Collections.sort(infos)
    infos.map { |info: FileInfo| info.ast }
  end

  #todo handle multiple packages in one file
  # parser allows packages to have bodies
  def enterPackage(node, _info)
    info = FileInfo(_info)
    info.pkg = node.name.identifier
    false
  end

  def enterImport(node, _info)
    info = FileInfo(_info)
    fullName = node.fullName.identifier
    simpleName = node.simpleName.identifier
    info.add_import fullName
    false
  end

  class FileInfo
    implements Comparable
    attr_reader ast: Node, pkg: String
    def initialize file_ast: Node
      @ast = file_ast
      @imports = []
    end

    def pkg= pkg: String
      ImportSorter.log.fine "already have a package for #{ast}" if @pkg
      @pkg ||= pkg
    end

    def add_import pkg: String
      @imports.add pkg
    end

    def has_import pkg: String
      @imports.contains pkg
    end

    def compareTo o
      other = FileInfo(o)
      return 0 if other.pkg == self.pkg
      return -1 if has_import other.pkg
      return 1 if other.has_import other.pkg
      return 0 # close enough
    end
  end
end