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

require 'java'
require 'mirah'

java_import 'java.util.List'

java_package "org.mirah"
class MirahCommand
  java_import 'java.lang.System'

  java_signature "void main(String[])"
  def self.main(args)
    rb_args = args.to_a
    command = rb_args.shift.to_s

    # force $0 to something explanatory
    $0 = "<mirah #{command}>"

    # for OS X, set property for Dock title
    System.setProperty("com.apple.mrj.application.apple.menu.about.name", "Mirah Runner")

    case command
    when "compile"
      MirahCommand.compile(rb_args)
    when "run"
      MirahCommand.run(rb_args)
    else
      $stderr.puts "Usage: compile <script> or run <script>"
    end
  end

  java_signature 'void compile(List args)'
  def self.compile(args)
    unless Mirah.compile *args
      raise "Compilation failed."
    end
  end

  java_signature 'void run(List args)'
  def self.run(args)
    Mirah.run(*args)
  end
end
