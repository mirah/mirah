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

module Mirah
  module Transform
    class Transformer
      begin
        java_import 'org.mirah.macros.Compiler'
      rescue NameError
        # builtins not compiled yet
      end

      attr_reader :errors, :state
      attr_accessor :filename

      def initialize(typer)
        @errors = []
        @tmp_count = 0
        @annotations = []
        @extra_body = nil
        @typer = typer
        @types = typer.type_system if typer
        @files = {""=>{:filename => "", :line => 0, :code => ""}}
      end

      def tmp(format="__xform_tmp_%d")
        format % [@tmp_count += 1]
      end

      class JMetaPosition
        attr_accessor :start_line, :end_line, :start_offset, :end_offset, :file
        attr_accessor :startpos, :endpos, :start_column, :end_column, :source

        def initialize(transformer, startpos, endpos, source)
          @startpos = startpos
          @endpos = endpos
          @transformer = transformer
          @start_line = startpos.line
          @start_offset = startpos.pos
          @start_column = startpos.col
          @end_line = endpos.line
          @end_offset = endpos.pos
          @end_column = endpos.col
          @source = source
        end
      end
    end
  end
end
