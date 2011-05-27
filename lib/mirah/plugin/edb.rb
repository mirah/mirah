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

require 'erb'

Mirah::AST.defmacro('def_edb') do |transformer, fcall, parent|
  name = fcall.parameters[0].name
  path = fcall.parameters[1].literal
  compiler = ERB::Compiler.new(nil)
  compiler.put_cmd = "_edbout.append"
  compiler.insert_cmd = "__edb_insert__ _edbout.append"
  compiler.pre_cmd = ["def #{name}", "_edbout = StringBuilder.new"]
  compiler.post_cmd = ["_edbout.toString", "end"]
  src = compiler.compile(IO.read(path))
  ast = Mirah::AST.parse_ruby(transformer, src, path)
  transformer.filename = path
  script = transformer.transform(ast, parent)
  script.body.parent = parent
  script.body
end

Mirah::AST.defmacro('__edb_insert__') do |transformer, fcall, parent|
  # ERB sticks in a .to_s that we don't want.
  # the ast is __edb_insert__(_edbout.append(content.to_s))
  append = fcall.parameters[0]
  content = append.parameters[0].target
  content.parent = append
  append.parameters = [content]
  append.parent = parent
  append
end

