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

require 'mirah/generator'
require 'fileutils'

module Mirah
  module Commands
    class Compile < Base
      def execute
        execute_base do
          generator = Mirah::Generator.new(@state, @state.compiler_class, true, @state.verbose)

          generator.generate(@state.args).each do |result|
            filename = "#{@state.destination}#{result.filename}"
            FileUtils.mkdir_p(File.dirname(filename))
            File.open(filename, 'wb') {|f| f.write(result.bytes)}
          end
        end
      end

      def command_name
        :compile
      end
    end
  end
end
