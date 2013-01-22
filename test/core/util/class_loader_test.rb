require 'test_helper'

class ClassLoaderTest < Test::Unit::TestCase
  FIXTURES = File.expand_path("#{__FILE__}/../../../fixtures/") +"/"
  A_CLASS = "#{FIXTURES}org/foo/A.class"

  def test_mirah_class_loader_find_class_in_map_successful
    class_map = {
      'org.foo.A' => Mirah::Util::ClassLoader.binary_string(File.open(A_CLASS, 'rb') {|f| f.read })
    }
    class_loader = Mirah::Util::ClassLoader.new nil, class_map
    cls = class_loader.load_class 'org.foo.A'
    assert_equal 'org.foo.A', cls.name
  end

  def test_mirah_class_loader_w_missing_class_raises_class_not_found
    class_loader = Mirah::Util::ClassLoader.new nil, {}

    ex = assert_raise java.lang.ClassNotFoundException do
      class_loader.find_class 'org.doesnt.exist.Class'
    end
  end


  def test_isolated_resource_loader_only_finds_resources_given_to_it
    loader = Mirah::Util::IsolatedResourceLoader.new [java.net.URL.new("file:#{FIXTURES}")]
    url = loader.get_resource "my.properties"
    assert_not_nil url
  end
end
