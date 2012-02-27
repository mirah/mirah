class TestAnnotations < Test::Unit::TestCase
  def deprecated
    @deprecated ||= java.lang.Deprecated.java_class
  end

  def test_annotation_on_a_method
    cls, = compile(<<-EOF)
      $Deprecated
      def foo
        'foo'
      end
    EOF

    assert_not_nil cls.java_class.java_method('foo').annotation(deprecated)
    assert_nil cls.java_class.annotation(deprecated)
  end
  
  def test_annotation_on_a_class
    cls, = compile(<<-EOF)
      $Deprecated
      class Annotated
      end
    EOF
    assert_not_nil cls.java_class.annotation(deprecated)
  end
  
  def test_annotation_on_a_field
    cls, = compile(<<-EOF)
      class AnnotatedField
        def initialize
          $Deprecated
          @foo = 1
        end
      end
    EOF

    assert_not_nil cls.java_class.declared_fields[0].annotation(deprecated)
  end
  
  def test_annotation_with_an_integer
    jruby_method = Java::OrgJrubyAnno::JRubyMethod.java_class

    cls, = compile(<<-EOF)
      import org.jruby.*
      import org.jruby.anno.*
      import org.jruby.runtime.*
      import org.jruby.runtime.builtin.*

      $JRubyMethod["name" => ["bar"], "optional" => 1]
      def bar(baz:int)
      end
    EOF
    method_annotation = cls.java_class.java_method('bar', :int).annotation(jruby_method)

    assert_equal 1, method_annotation.optional
  end

end