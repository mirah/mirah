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

package org.mirah.tool

import mirah.lang.ast.StringCodeSource
import java.nio.charset.Charset
import java.io.FileInputStream
import java.io.InputStream
import java.io.BufferedReader

class EncodedCodeSource < StringCodeSource


  def initialize(file_name: String, io:InputStream, encoding:String)
    super(file_name, readToString(io, encoding))
  end

  def initialize(file_name:String, encoding:String)
    initialize(file_name, FileInputStream.new(file_name), encoding)
  end

  def initialize(file_name:String)
    initialize(file_name, FileInputStream.new(file_name), Charset.defaultCharset.name)
  end

  def initialize(file_name: String, io:InputStream)
    initialize(file_name, io, Charset.defaultCharset.name)
  end

  def self.DEFAULT_CHARSET:String
    'utf-8'
  end

  def self.readToString(stream:InputStream, encoding: String):String
    reader = java::io::BufferedReader.new(java::io::InputStreamReader.new(stream, encoding) )
    buffer = char[8192]
    builder = StringBuilder.new
    while (read = reader.read(buffer, 0, buffer.length)) > 0
      builder.append(buffer, 0, read);
    end
    return builder.toString
  end

end