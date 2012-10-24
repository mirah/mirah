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

class BiteScript::MethodBuilder
  def inot
    iconst_m1
    ixor
  end

  def lnot
    # TODO would any of these be faster?
    #   iconst_m1; i2l
    #   lconst_1; lneg
    ldc_long(-1)
    ixor
  end

  def op_to_bool
    done_label = label
    true_label = label

    yield(true_label)
    iconst_0
    goto(done_label)
    true_label.set!
    iconst_1
    done_label.set!
  end
end
