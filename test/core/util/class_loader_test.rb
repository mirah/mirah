require 'test_helper'

class ClassLoaderTest < Test::Unit::TestCase
  def test_mirah_class_loader_find_class_in_map_successful
    class_map = {
      'org.foo.A' => Mirah::Util::ClassLoader.binary_string(File.open(File.expand_path("#{__FILE__}/../fixtures/org/foo/A.class"), 'rb') {|f| f.read })
    }
    class_loader = Mirah::Util::ClassLoader.new nil, class_map
    cls = class_loader.load_class 'org.foo.A'
    assert_equal 'org.foo.A', cls.name
  end

  def test_mirah_class_loader_w_missing_class_raises_class_not_found
    class_loader = Mirah::Util::ClassLoader.new nil, {}

    ex = assert_raise NativeException do
      class_loader.find_class 'org.doesnt.exist.Class'
    end
    assert_equal java.lang.ClassNotFoundException, ex.cause.class
  end
end
