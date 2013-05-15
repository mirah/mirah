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
require 'bundler/setup'
require 'test/unit'
require 'mirah'
require 'jruby'
require 'stringio'
require 'fileutils'

module CommonAssertions
  import java.lang.System
  import java.io.PrintStream

  def assert_include(value, array, message=nil)
    message = build_message message, '<?> does not include <?>', array, value
    assert_block message do
      array.include? value
    end
  end

  def capture_output
    saved_output = System.out
    saved_stdout = $stdout
    saved_stderr = $stderr
    output = StringIO.new
    System.setOut(PrintStream.new(output.to_outputstream))
    $stdout = output
    $stderr = output
    begin
      yield
      output.rewind
      output.read
    ensure
      System.setOut(saved_output)
      $stdout = saved_stdout
      $stderr = saved_stderr
    end
  end

  def assert_output(expected, &block)
    assert_equal(expected, capture_output(&block))
  end

end

class Test::Unit::TestCase
  include CommonAssertions
end
