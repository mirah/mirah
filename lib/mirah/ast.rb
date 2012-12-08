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

require 'mirah/util/delegate'
require 'mirah/transform'
require 'mirah/ast/scope'

module Mirah
  module AST
    class << self
      attr_accessor :verbose
    end

    java_import 'mirah.lang.ast.Array'
    java_import 'mirah.lang.ast.Annotation'
    java_import 'mirah.lang.ast.Constant'
    java_import 'mirah.lang.ast.EmptyArray'
    java_import 'mirah.lang.ast.Fixnum'
    java_import 'mirah.lang.ast.HashEntry'
    java_import 'mirah.lang.ast.LocalAccess'
    java_import 'mirah.lang.ast.Node'
    java_import 'mirah.lang.ast.NodeList'
    java_import 'mirah.lang.ast.Noop'
    java_import 'mirah.lang.ast.OptionalArgument'
    java_import 'mirah.lang.ast.Position'
    java_import 'mirah.lang.ast.SimpleString'
    java_import 'mirah.lang.ast.TypeName'
    java_import 'mirah.lang.ast.TypeRef'

  end
end
