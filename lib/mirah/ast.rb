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

require 'delegate'
require 'mirah/transform'
require 'mirah/ast/scope'

module Mirah
  module AST
    class << self
      attr_accessor :verbose
    end

    # The top of the AST class hierarchy, this represents an abstract AST node.
    # It provides accessors for _children_, an array of all child nodes,
    # _parent_, a reference to this node's parent (nil if none), and _newline_,
    # whether this node represents a new line.
    java_import 'mirah.lang.ast.Node'
    java_import 'mirah.lang.ast.Fixnum'
    java_import 'mirah.lang.ast.EmptyArray'
    java_import 'mirah.lang.ast.OptionalArgument'

    class TypeReference
    end
    class TypeDefinition < TypeReference
    end
  end
end