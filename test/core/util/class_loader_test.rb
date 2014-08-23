# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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
require 'test_helper'

class ClassLoaderTest < Test::Unit::TestCase
  java_import 'org.mirah.MirahClassLoader'
  java_import 'org.mirah.IsolatedResourceLoader'

  FIXTURES = File.expand_path("#{__FILE__}/../../../fixtures/") +"/"
  A_CLASS = "#{FIXTURES}org/foo/A.class"

  def test_mirah_class_loader_find_class_in_map_successful
    class_map = {
      'org.foo.A' => File.open(A_CLASS, 'rb') {|f| java.lang.String.new f.read.to_java_bytes, "ISO-8859-1" }
    }
    class_loader = MirahClassLoader.new nil, class_map
    cls = class_loader.load_class 'org.foo.A'
    assert_equal 'org.foo.A', cls.name
  end

  def test_mirah_class_loader_w_missing_class_raises_class_not_found
    class_loader = MirahClassLoader.new nil, {}

    begin
      klass = class_loader.find_class 'org.doesnt.exist.Class'
      fail 'Expected ClassNotFoundException'
    rescue java.lang.ClassNotFoundException
      # expected
    end
  end

  def test_isolated_resource_loader_only_finds_resources_given_to_it
    loader = IsolatedResourceLoader.new [java.net.URL.new("file:#{FIXTURES}")]
    url = loader.get_resource "my.properties"
    assert_not_nil url
  end
end
