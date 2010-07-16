require 'test/unit'
require 'mirah'

class TestEnv < Test::Unit::TestCase
  include Duby

  def test_path_seperator
    # Check that env var PATH_SEPERATOR is used
    RbConfig::CONFIG['PATH_SEPARATOR'] = '*'
    assert_equal('*', Duby::Env.path_seperator)

    # Check that : (colon) is returned if no PATH_SEPERATOR env var set
    RbConfig::CONFIG['PATH_SEPARATOR'] = ''
    assert_equal(':', Duby::Env.path_seperator)
  end

  def test_encode_paths
    RbConfig::CONFIG['PATH_SEPARATOR'] = ':'
    
    assert_equal('a:b:c', Duby::Env.encode_paths(['a','b','c']))
    assert_equal('a', Duby::Env.encode_paths(['a']))
    assert_equal('', Duby::Env.encode_paths([]))

    RbConfig::CONFIG['PATH_SEPARATOR'] = ';'

    assert_equal('a;b;c', Duby::Env.encode_paths(['a','b','c']))
  end

  def test_decode_paths
    RbConfig::CONFIG['PATH_SEPARATOR'] = ':'

    path_array = ['1','2']
    assert_equal(['1','2','a','b','c','d'], Duby::Env.decode_paths('a:b:c:d', path_array))
    assert_equal(['1','2','a','b','c','d'], path_array)

    assert_equal(['a','b','c','d'], Duby::Env.decode_paths('a:b:c:d'))
    assert_equal(['a'], Duby::Env.decode_paths('a'))

    RbConfig::CONFIG['PATH_SEPARATOR'] = ';'
    assert_equal(['a','b','c','d'], Duby::Env.decode_paths('a;b;c;d'))
  end
end