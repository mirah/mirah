# Copyright (c) 2010-2014 The Mirah project authors. All Rights Reserved.
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

require 'fileutils'
require 'rbconfig'

$CLASSPATH << ENV.fetch('MIRAHC_JAR',File.expand_path("../../dist/mirahc.jar",__FILE__))

require 'mirah/version'
require 'mirah/transform'
require 'mirah/env'
require 'mirah/errors'
require 'mirah/typer'

require "mirah/util/process_errors"
require "mirah/util/logging"

module Mirah
  java_import 'org.mirah.tool.RunCommand'
  java_import 'org.mirah.tool.Mirahc'

  def self.run(*args)
    Mirah::RunCommand.run(args)
  end

  def self.compile(*args)
    Mirah::Mirahc.new.compile(args)
  end

  def self.plugins
    @plugins ||= []
  end

  def self.reset
    plugins.each {|x| x.reset if x.respond_to?(:reset)}
  end

  def self.print_error(message, position)
    if position.nil?
      puts message
      return
    end
    puts "#{position.source.name}:#{position.start_line}: #{message}"
    puts underline(position)
  end

  def self.underline(position)
    start_line = position.start_line - position.source.initial_line
    end_line = position.end_line - position.source.initial_line

    start_col = position.start_column
    end_col = position.end_column
    adjustment = if start_line == 0
      position.source.initial_column
    else
      1
    end

    start_col -= adjustment
    end_col -= adjustment

    result = ""
    position.source.contents.each_line.with_index do |line, lineno|
      break if lineno > end_line
      next if lineno < start_line

      chomped = line.chomp
      result << chomped
      result << "\n"

      start = 0
      start = start_col if lineno == start_line

      result << " " * start

      endcol = chomped.size
      endcol = end_col if lineno == end_line

      result << "^" * [endcol - start, 1].max

      result << "\n"
    end
    result
  end
end
