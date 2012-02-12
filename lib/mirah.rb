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
require 'bitescript'

require 'mirah/version'
require 'mirah/transform'
require 'mirah/ast'
require 'mirah/compiler'
require 'mirah/env'
require 'mirah/errors'
require 'mirah/typer'
require 'mirah/jvm/types'

require 'mirah/jvm/compiler'
#Dir[File.dirname(__FILE__) + "/mirah/plugin/*"].each {|file| require "#{file}" if file =~ /\.rb$/}
require 'jruby'

require 'mirah/commands'

module Mirah
  def self.run(*args)
    Mirah::Commands::Run.new(args).execute
  end

  def self.compile(*args)
    Mirah::Commands::Compile.new(args).execute
  end

  def self.parse(*args)
    Mirah::Commands::Parse.new(args).execute
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
    puts "#{position.filename}:#{position.start_line}: #{message}"
    #puts position.underline
  end
end
