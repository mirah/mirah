class AnnotationsTest < Test::Unit::TestCase
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
    cls, = compile(<<-EOF)
      import org.foo.IntAnno
      class IntValAnnotation
        $IntAnno[name: "bar", value: 1]
        def bar
        end
      end
      method = IntValAnnotation.class.getMethod("bar")
      anno = method.getAnnotation(IntAnno.class)
      puts anno.value
    EOF

    assert_run_output("1\n", cls)
  end

  def test_annotation_from_constant
    return
    cls, = compile(<<-EOF)
      import org.foo.IntAnno
      class IntValAnnotation
        Value = 1
        $IntAnno[name: "bar", value: Value]
        def bar
        end
      end
      method = IntValAnnotation.class.getMethod("bar")
      anno = method.getAnnotation(IntAnno.class)
      puts anno.value
    EOF

    assert_run_output("1\n", cls)
  end

  
  def test_override_def_method_does_not_fire_on_actual_override
    cls, = compile(%q'
      class AnySuper
        def foo(a:int, b:java::util::List = nil)
          "abc"
        end
      end
      
      class TestOverrideAnnotation < AnySuper

        $java.lang.Override # <- this is ugly
        def foo(a:int)
          "xy#{a}z"
        end
        
        $java.lang.Override
        def foo(a:int, b:java::util::List)
          "xy#{a}z#{b.size}"
        end
        
        $java.lang.Override
        def hashCode:int
          7
        end
        
        $java.lang.Override
        def equals(o:Object):boolean
          false
        end
      end
      
      a = TestOverrideAnnotation.new
      puts a.foo(4)
      puts a.foo(5, [])
      puts a.hashCode
      puts a.equals(a)
    ')
    assert_run_output("xy4z\nxy5z0\n7\nfalse\n", cls)
  end
  
  def test_override_def_method_does_fire_on_missing_override
    assert_raise_java(Mirah::MirahError, /requires to override a method, but no matching method is actually overridden/) do
      cls, = compile(%q'
        class AnySuper
          def foo(a:int, b:java::util::List = nil)
            "abc"
          end
        end
        
        class TestOverrideAnnotation < AnySuper

          $java.lang.Override
          def foo(a:int, b:java::util::ArrayList)
            "xy#{a}z#{b.size}"
          end
        end
        
        a = TestOverrideAnnotation.new
        puts a.foo(5, [])
      ')
    end
    assert_raise_java(Mirah::MirahError, /requires to override a method, but no matching method is actually overridden/) do
      cls, = compile(%q'
        class A
          $Override # Try without fully qualified class name.
          def go
          end
        end
      ')
    end
  end
end
