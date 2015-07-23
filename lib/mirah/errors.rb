# Copyright (c) 2010-2013 The Mirah project authors. All Rights Reserved.
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
  class MirahError < StandardError
    attr_accessor :position
    attr_accessor :diagnostic
    attr_accessor :cause

    def initialize(message, position=nil, diagnostic=nil)
      super(message)
      @position = position
      @diagnostic = diagnostic
    end

    def inspect
      "MirahError: #{message} #{position}"
    end
  end

  class NodeError < MirahError
    attr_reader :node

    def initialize(message, node=nil)
      position = node.position if node
      super(message, position)
      @node = node
    end

    def node=(node)
      @position = node.position if node
      @node     = node
    end

    def self.wrap(ex, node)
      case ex
      when NodeError
        ex.node ||= node
        ex
      when MirahError
        ex.position ||= node.position
        ex
      else
        new_ex = new(ex.message, node)
        new_ex.cause      = ex
        new_ex.position ||= ex.position if ex.respond_to?(:position)
        new_ex.set_backtrace(ex.backtrace)
        new_ex
      end
    end

    def position
      if node && node.position
        node.position
      else
        super
      end
    end
  end

  class SyntaxError < NodeError
  end

  class InferenceError < NodeError
  end

  class InternalCompilerError < NodeError
  end
end
