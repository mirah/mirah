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
  module AST
    class If
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.branch(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Condition
      def compile(compiler, expression)
        # TODO: can a condition ever be an expression? I don't think it can...
        compiler.line(line_number)
        predicate.compile(compiler, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Loop
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.loop(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Return
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.return(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Break
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.break(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Next
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.next(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Redo
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.redo(self)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Raise
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler._raise(exception)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Rescue
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.rescue(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end

    class Ensure
      def compile(compiler, expression)
        compiler.line(line_number)
        compiler.ensure(self, expression)
      rescue Exception => ex
        raise Mirah::InternalCompilerError.wrap(ex, self)
      end
    end
  end
end