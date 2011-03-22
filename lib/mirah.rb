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

require 'fileutils'
require 'rbconfig'
require 'mirah/version'
require 'mirah/transform'
require 'mirah/ast'
require 'mirah/typer'
require 'mirah/compiler'
require 'mirah/env'
require 'mirah/errors'
require 'mirah/class_loader'
begin
  require 'bitescript'
rescue LoadError
  $: << File.dirname(__FILE__) + '/../../bitescript/lib'
  require 'bitescript'
end
require 'mirah/jvm/compiler'
require 'mirah/jvm/typer'
Dir[File.dirname(__FILE__) + "/mirah/plugin/*"].each {|file| require "#{file}" if file =~ /\.rb$/}
require 'jruby'

require 'mirah/commands'

module Mirah
  def self.run(*args)
    Mirah::Commands::Run.new.execute(*args)
  end

  def self.compile(*args)
    Mirah::Commands::Compile.new.execute(*args)
  end

  def self.parse(*args)
    Mirah::Commands::Parse.new.execute(*args)
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
    puts "#{position.file}:#{position.start_line}: #{message}"
    file_offset = 0
    startline = position.start_line - 1
    endline = position.end_line - 1
    start_col = position.start_col - 1
    end_col = position.end_col - 1
    # don't try to search dash_e
    # TODO: show dash_e source the same way
    if File.exist? position.file
      File.open(position.file).each_with_index do |line, lineno|
        if lineno >= startline && lineno <= endline
          puts line.chomp
          if lineno == startline
            print ' ' * start_col
          else
            start_col = 0
          end
          if lineno < endline
            puts '^' * (line.size - start_col)
          else
            puts '^' * [end_col - start_col, 1].max
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  Mirah.run(ARGV[0], *ARGV[1..-1])
end
