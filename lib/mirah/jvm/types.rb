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

require 'bitescript'
require 'mirah/ast'
require 'mirah/jvm/method_lookup'
require 'mirah/util/logging'
#require 'mirah/jvm/compiler'
require 'set'
module Mirah::JVM
  module Types
  end
end
require 'mirah/jvm/types/type'
require 'mirah/jvm/types/primitive_type'
require 'mirah/jvm/types/meta_type'
require 'mirah/jvm/types/null_type'
require 'mirah/jvm/types/implicit_nil_type'
require 'mirah/jvm/types/unreachable_type'
require 'mirah/jvm/types/void_type'
require 'mirah/jvm/types/block_type'
require 'mirah/jvm/types/array_type'
require 'mirah/jvm/types/dynamic_type'
require 'mirah/jvm/types/type_definition'
require 'mirah/jvm/types/interface_definition'
require 'mirah/jvm/types/intrinsics'
require 'mirah/jvm/types/methods'
require 'mirah/jvm/types/number'
require 'mirah/jvm/types/integers'
require 'mirah/jvm/types/boolean'
require 'mirah/jvm/types/floats'
require 'mirah/jvm/types/literals'
require 'mirah/jvm/types/factory'
