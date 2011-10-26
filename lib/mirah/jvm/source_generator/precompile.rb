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

require 'mirah/ast'

module Mirah::AST
  class TempValue
    def initialize(node, compiler=nil, value=nil)
      if compiler.nil?
        @tempname = node
      else
        @tempname = compiler.temp(node, value)
        @tempvalue = value || node
      end
    end

    def compile(compiler, expression)
      if expression
        compiler.method.print @tempname
      end
    end

    def reload(compiler)
      compiler.assign(@tempname, @tempvalue)
    end
  end

  module Node
    def expr?(compiler)
      true
    end

    def precompile(compiler)
      if expr?(compiler)
        self
      else
        temp(compiler)
      end
    end

    def temp(compiler, value=nil)
      TempValue.new(self, compiler, value)
    end
  end

  class Body
    def expr?(compiler)
      false
    end
  end

  class If
    def expr?(compiler)
      return false unless condition.predicate.expr?(compiler)
      return false unless body.nil? || body.expr?(compiler)
      return false unless self.else.nil? || self.else.expr?(compiler)
      true
    end
  end

  class Loop
    def expr?(compiler)
      false
    end

    def precompile(compiler)
      compile(compiler, false)
      temp(compiler, 'null')
    end
  end

  class Call
    def method(compiler=nil)
      @method ||= begin
        arg_types = parameters.map {|p| p.inferred_type}
        target.inferred_type.get_method(name, arg_types)
      end
    end

    def expr?(compiler)
      target.expr?(compiler) &&
          parameters.all? {|p| p.expr?(compiler)} &&
          cast || (
            !method.return_type.kind_of?(Mirah::AST::InlineCode) &&
            !method.return_type.void?)
    end

    def precompile_target(compiler)
      if method.return_type.void? && target.expr?(compiler)
        TempValue.new(target, compiler)
      else
        target.precompile(compiler)
      end
    end
  end

  class FunctionalCall
    def method(compiler)
      @method ||= begin
        arg_types = parameters.map {|p| p.inferred_type}
        @self_type.get_method(name, arg_types)
      end
    end

    def expr?(compiler)
      parameters.all? {|p| p.expr?(compiler)} &&
          (cast? || !method(compiler).return_type.void?)
    end
  end

  # TODO merge with FunctionalCall logic (almost identical)
  class Super
    def method(compiler)
      @method ||= begin
        arg_types = parameters.map {|p| p.inferred_type}
        compiler.self_type.superclass.get_method(name, arg_types)
      end
    end

    def expr?(compiler)
      parameters.all? {|p| p.expr?(compiler)} &&
          !method(compiler).return_type.void?
    end
  end

  class EmtpyArray
    def expr?(compiler)
      size.expr?(compiler)
    end
  end

  class LocalAssignment
    def expr?(compiler)
      compiler.method.local?(name) && value.expr?(compiler)
    end

    def precompile(compiler)
      if expr?(compiler)
        self
      else
        compile(compiler, false)
        TempValue.new(name)
      end
    end
  end

  class ToString
    def expr?(compiler)
      body.expr?(compiler)
    end

    def temp(compiler, value=nil)
      TempValue.new(body, compiler, value)
    end
  end

  class StringConcat
    def expr?(compiler)
      children.all? {|x| x.expr?(compiler)}
    end
  end

  class Return
    def expr?(compiler)
      false
    end
  end

  class Raise
    def expr?(compiler)
      false
    end
  end

  class Rescue
    def expr?(compiler)
      false
    end
  end

  class Ensure
    def expr?(compiler)
      false
    end
  end

  class FieldAssignment
    def expr?(compiler)
      false
    end
  end

  class Colon2
    def expr?(compiler)
      true
    end
  end
end