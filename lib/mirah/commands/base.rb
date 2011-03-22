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

require 'mirah/argument_processor'
require 'mirah/compilation_state'
require 'mirah/parser'
require 'mirah/compiler'
require 'mirah/generator'

module Mirah
  module Commands
    class Base
      def initialize(args)
        Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
        @state = Mirah::CompilationState.new
        @args = args
        @argument_processor = Mirah::ArgumentProcessor.new(@state, @args)
      end
      
      attr_accessor :state, :args, :argument_processor
      
      def execute_base
        argument_processor.process
        yield
      rescue Mirah::InternalCompilerError => ice
        Mirah.print_error(ice.message, ice.position) if ice.node
        raise ice
      rescue Mirah::MirahError => ex
        Mirah.print_error(ex.message, ex.position)
        puts ex.backtrace if state.verbose
      end
    end
  end
end