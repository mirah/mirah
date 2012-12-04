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
require 'mirah/jvm/compiler/base'
require 'mirah/jvm/method_lookup'
require 'mirah/jvm/types'
require 'bitescript'
require 'mirah/jvm/compiler/jvm_bytecode'
require 'mirah/transform/ast_ext'

module Mirah
  module AST
    class FunctionalCall
      attr_accessor :target
    end

    class Super
      attr_accessor :target
    end
  end
end

module Mirah
  module JVM
    module Compiler
      begin
        java_import 'org.mirah.jvm.compiler.Backend'
      rescue NameError
        $CLASSPATH << File.dirname(__FILE__) + '/../../../javalib/mirah-compiler.jar'
        begin
          java_import 'org.mirah.jvm.compiler.Backend'
        rescue
	        puts "Unable to load new Backend"
        end
      end
    end
  end
end
