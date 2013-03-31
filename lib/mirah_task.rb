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

require 'mirah'

module Mirah
  class PathArray < Array
    def <<(value)
      super(File.expand_path(value))
    end
  end

  def self.source_path
    source_paths[0] ||= File.expand_path('.')
  end

  def self.source_paths
    @source_paths ||= PathArray.new
  end

  def self.source_path=(path)
    source_paths[0] = File.expand_path(path)
  end

  def self.dest_paths
    @dest_paths ||= PathArray.new
  end

  def self.dest_path
    dest_paths[0] ||= File.expand_path('.')
  end

  def self.dest_path=(path)
    dest_paths[0] = File.expand_path(path)
  end

  def self.find_dest(path)
    expanded = File.expand_path(path)
    dest_paths.each do |destdir|
      if expanded =~ /^#{destdir}\//
        return destdir
      end
    end
  end

  def self.find_source(path)
    expanded = File.expand_path(path)
    source_paths.each do |sourcedir|
      if expanded =~ /^#{sourcedir}\//
        return sourcedir
      end
    end
  end

  def self.dest_to_source_path(target_path)
    destdir = find_dest(target_path)
    path = File.expand_path(target_path).sub(/^#{destdir}\//, '')
    path.sub!(/\.(java|class)$/, '')
    snake_case = File.basename(path).gsub(/[A-Z]/, '_\0').sub(/_/, '').downcase
    snake_case = "#{File.dirname(path)}/#{snake_case}"
    source_paths.each do |source_path|
      ["mirah", "duby"].each do |suffix|
        filename = "#{source_path}/#{path}.#{suffix}"
        return filename if File.exist?(filename)
        filename = "#{source_path}/#{snake_case}.#{suffix}"
        return filename if File.exist?(filename)
      end
    end
    # No source file exists. Just go with the first source path and .mirah
    return "#{self.source_path}/#{path}.mirah"
  end

  def self.compiler_options
    @compiler_options ||= []
  end

  def self.compiler_options=(args)
    @compiler_options = args
  end
end

def mirahc(*files)
  if files[-1].kind_of?(Hash)
    options = files.pop
  else
    options = {}
  end
  source_dir = options.fetch(:dir, Mirah.source_path)
  dest = File.expand_path(options.fetch(:dest, Mirah.dest_path))
  files = files.map {|f| File.expand_path(f).sub(/^#{source_dir}\//, '')}
  flags = options.fetch(:options, Mirah.compiler_options)
  args = ['-d', dest, *flags] + files
  chdir(source_dir) do
    puts "mirahc #{args.join ' '}"
    Mirah.compile(*args) || exit(1)
    Mirah.reset
  end
end

rule '.class' => [proc {|n| Mirah.dest_to_source_path(n)}] do |t|
  mirahc(t.source,
         :dir=>Mirah.find_source(t.source),
         :dest=>Mirah.find_dest(t.name))
end
