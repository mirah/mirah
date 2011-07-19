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

require 'mirah/util/process_errors'
require 'mirah/transform'
require 'java'

module Mirah
  class Parser
    include Mirah::Util::ProcessErrors
    
    def initialize(state, logging)
      @transformer = Mirah::Transform::Transformer.new(state)
      Java::MirahImpl::Builtin.initialize_builtins(@transformer)
      @logging = logging
      @verbose = state.verbose
    end
    
    attr_accessor :transformer, :logging
    
    def parse_from_args(files_or_scripts)
      nodes = []
      inline = false
      puts "Parsing..." if logging
      expand_files(files_or_scripts).each do |script|
        if script == '-e'
          inline = true
          next
        elsif inline
          nodes << parse_inline(script)
          break
        else
          nodes << parse_file(script)
        end
      end
      raise 'nothing to parse? ' + files_or_scripts.inspect unless nodes.length > 0
      nodes
    end
    
    def parse_inline(source)
      puts "  <inline script>" if logging
      parse_and_transform('DashE', source)
    end
    
    def parse_file(filename)
      puts "  #{filename}" if logging
      parse_and_transform(filename, File.read(filename))
    end
    
    def parse_and_transform(filename, src)
      parser_ast = Mirah::AST.parse_ruby(src, filename)
      
      transformer.filename = filename
      mirah_ast = transformer.transform(parser_ast, nil)
      process_errors(transformer.errors)
      
      mirah_ast
    end
      
    def expand_files(files_or_scripts)
      expanded = []
      files_or_scripts.each do |filename|
        if File.directory?(filename)
          Dir[File.join(filename, '*')].each do |child|
            if File.directory?(child)
              files_or_scripts << child
            elsif child =~ /\.(duby|mirah)$/
              expanded << child
            end
          end
        else
          expanded << filename
        end
      end
      expanded
    end
  end
end