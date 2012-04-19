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

#require 'mirah/jvm/types'
require 'mirah/util/compilation_state'
require 'mirah/util/argument_processor'
require 'mirah/errors'

module Mirah
  module Commands
    class Base
      include Mirah::Logging::Logged
      def initialize(args)
        #Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
        @state = Mirah::Util::CompilationState.new
        @state.command = command_name
        @args = args
        @argument_processor = Mirah::Util::ArgumentProcessor.new(@state, @args)
      end
      
      attr_accessor :state, :args, :argument_processor
      
      def execute_base
        # because MirahCommand is a JRuby Java class, SystemExit bubbles through and makes noise
        # so we use a catch/throw to early exit instead
        # see util/process_errors.rb
        status = catch(:exit) do
          begin
            argument_processor.process
            yield
          rescue Mirah::InternalCompilerError => ice
            Mirah.print_error(ice.message, ice.position) if ice.node
            raise ice.cause || ice
          rescue Mirah::MirahError => ex
            Mirah.print_error(ex.message, ex.position)
            log "{0}\n{1}", [ex.message, ex.backtrace.join("\n")]
            throw :exit, 1
          end
          0
        end
        exit status if status > 0
        true
      end
    end
  end
end