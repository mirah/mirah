require 'test/unit'
require 'java'

$CLASSPATH << 'build/mirah-parser.jar'

class TestParsing < Test::Unit::TestCase
  java_import 'org.mirahparser.mmeta.SyntaxError'
  java_import 'org.mirahparser.mmeta.BaseParser'
  java_import 'mirahparser.impl.MirahParser'
  java_import 'mirahparser.lang.ast.NodeScanner'

  class AstPrinter < NodeScanner
    def initialize
      @out = ""
    end
    def enterNullChild(obj)
      @out << ", null"
    end
    def enterDefault(node, arg)
      @out << ", " unless node == arg
      @out << "[" << node.java_class.simple_name
      true
    end
    def exitDefault(node, arg)
      @out << "]"
    end
    %w(Boolean Fixnum Float CharLiteral SimpleString SimpleString).each do |name|
      eval(<<-EOF)
        def enter#{name}(node, arg)
          enterDefault(node, arg)
          @out << ", "
          @out << node.value.to_s
          true
        end
      EOF
    end
    def enterBlockArgument(node, arg)
      enterDefault(node, arg)
      @out << ", optional" if node.optional
      true
    end
    def enterLoop(node, arg)
      enterDefault(node, arg)
      @out << ", skipFirstCheck" if node.skipFirstCheck
      @out << ", negative" if node.negative
      true
    end
    def exitFieldAccess(node, arg)
      @out << ", static" if node.isStatic
      exitDefault(node, arg)
    end
    alias exitFieldAssign exitFieldAccess
  end

  def parse(text)
    Java::MirahparserImpl::MirahParser.new.parse(text)
  end

  def assert_parse(expected, text)
    ast = parse(text)
    str = AstPrinter.new.scan(ast, ast)
    assert_equal(expected, str)
  end

  def assert_fails(text)
    begin
      fail("Should raise syntax error, but got #{parse text}")
    rescue SyntaxError
      # ok
    end
  end

  def test_fixnum
    assert_parse("[Script, [Fixnum, 0]]", '0')
    assert_parse("[Script, [Fixnum, 100]]", '1_0_0')
    assert_parse("[Script, [Fixnum, 15]]", '0xF')
    assert_parse("[Script, [Fixnum, 15]]", '0Xf')
    assert_parse("[Script, [Fixnum, 15]]", '017')
    assert_parse("[Script, [Fixnum, 15]]", '0o17')
    assert_parse("[Script, [Fixnum, 15]]", '0b1111')
    assert_parse("[Script, [Fixnum, 15]]", '0d15')
    assert_parse("[Script, [Fixnum, -15]]", '-15')
    assert_parse("[Script, [Fixnum, 2800088046]]", '2800088046')
    assert_fails "0X"
    # assert_fails "0_"
    # assert_fails "0b1_"
    # assert_fails "0d_1"
  end

  def test_statements
    code = <<EOF
1
  2
        
3  


EOF
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2], [Fixnum, 3]]]", code)
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2]]]", "1; 2")
    ast = parse(code)
    assert_equal(1, ast.body.get(0).position.start_line)
    assert_equal(1, ast.body.get(0).position.start_column)
    assert_equal(1, ast.body.get(0).position.end_line)
    assert_equal(2, ast.body.get(0).position.end_column)
    assert_equal(2, ast.body.get(1).position.start_line)
    assert_equal(3, ast.body.get(1).position.start_column)
    assert_equal(2, ast.body.get(1).position.end_line)
    assert_equal(4, ast.body.get(1).position.end_column)
    assert_equal(4, ast.body.get(2).position.start_line)
    assert_equal(1, ast.body.get(2).position.start_column)
    assert_equal(4, ast.body.get(2).position.end_line)
    assert_equal(2, ast.body.get(2).position.end_column)
    assert_parse("[Script, null]", "# foo")
  end

  def test_position
    ast = parse("\n  foo  ")
    assert_equal("foo", ast.body.name.identifier)
    assert_equal(2, ast.body.position.start_line)
    assert_equal(3, ast.body.position.start_column)
    assert_equal(2, ast.body.position.end_line)
    assert_equal(6, ast.body.position.end_column)
  end

  def test_symbol
    assert_parse("[Script, [SimpleString, foo]]", ':foo')
    assert_parse("[Script, [SimpleString, bar]]", ':bar')
    assert_parse("[Script, [SimpleString, @bar]]", ':@bar')
    assert_parse("[Script, [SimpleString, @@cbar]]", ':@@cbar')
    assert_fails(":")
  end

  def test_variable
    assert_parse("[Script, [Boolean, true]]", 'true')
    assert_parse("[Script, [Boolean, false]]", 'false')
    assert_parse("[Script, [Null]]", 'nil')
    assert_parse("[Script, [Self]]", 'self')
    assert_parse("[Script, [FieldAccess, [SimpleString, foo]]]", '@foo')
    assert_parse("[Script, [FieldAccess, [SimpleString, bar]]]", '@bar')
    assert_parse("[Script, [FieldAccess, [SimpleString, cfoo], static]]", '@@cfoo')
    assert_parse("[Script, [FieldAccess, [SimpleString, cbar], static]]", '@@cbar')
    assert_parse("[Script, [FunctionalCall, [SimpleString, a], [NodeList], null]]", 'a')
    assert_parse("[Script, [FunctionalCall, [SimpleString, b], [NodeList], null]]", 'b')
    assert_parse("[Script, [FunctionalCall, [SimpleString, end_pos], [NodeList], null]]", 'end_pos')
    assert_parse("[Script, [Constant, [SimpleString, A]]]", 'A')
    assert_parse("[Script, [Constant, [SimpleString, B]]]", 'B')
    assert_parse("[Script, [FunctionalCall, [SimpleString, B!], [NodeList], null]]", 'B!')
    assert_parse("[Script, [FunctionalCall, [SimpleString, def?], [NodeList], null]]", 'def?')
    assert_fails("BEGIN")
    assert_fails("until")
    assert_fails("def!=")
  end

  def test_float
    assert_parse("[Script, [Float, 1.0]]", "1.0")
    assert_parse("[Script, [Float, 0.0]]", "0e1")
    assert_parse("[Script, [Float, 10.0]]", "1e0_1")
    assert_parse("[Script, [Float, 320.0]]", "3_2e0_1")
    assert_parse("[Script, [Float, 422.2]]", "4_2.2_2e0_1")
    assert_fails("1.")
  end

  def test_strings
    assert_parse("[Script, [CharLiteral, 97]]", "?a")
    assert_parse("[Script, [CharLiteral, 65]]", "?A")
    assert_parse("[Script, [CharLiteral, 63]]", "??")
    assert_parse("[Script, [CharLiteral, 8364]]", "?â‚¬")
    assert_parse("[Script, [CharLiteral, 119648]]", "?í ´í½ ")
    assert_parse("[Script, [CharLiteral, 10]]", "?\\n")
    assert_parse("[Script, [CharLiteral, 32]]", "?\\s")
    assert_parse("[Script, [CharLiteral, 13]]", "?\\r")
    assert_parse("[Script, [CharLiteral, 9]]", "?\\t")
    assert_parse("[Script, [CharLiteral, 11]]", "?\\v")
    assert_parse("[Script, [CharLiteral, 12]]", "?\\f")
    assert_parse("[Script, [CharLiteral, 8]]", "?\\b")
    assert_parse("[Script, [CharLiteral, 7]]", "?\\a")
    assert_parse("[Script, [CharLiteral, 27]]", "?\\e")
    assert_parse("[Script, [CharLiteral, 10]]", "?\\012")
    assert_parse("[Script, [CharLiteral, 18]]", "?\\x12")
    assert_parse("[Script, [CharLiteral, 8364]]", "?\\u20ac")
    assert_parse("[Script, [CharLiteral, 119648]]", "?\\U0001d360")
    assert_parse("[Script, [CharLiteral, 91]]", "?\\[")
    assert_fails("?aa")
    assert_parse("[Script, [SimpleString, ]]", "''")
    assert_parse("[Script, [SimpleString, a]]", "'a'")
    assert_parse("[Script, [SimpleString, \\'\\n]]", "'\\\\\\'\\n'")
    assert_fails("'")
    assert_fails("'\\'")
  end

  def test_dquote_strings
    assert_parse("[Script, [SimpleString, ]]", '""')
    assert_parse("[Script, [SimpleString, a]]", '"a"')
    assert_parse("[Script, [SimpleString, \"]]", '"\\""')
    assert_parse("[Script, [SimpleString, \\]]", '"\\\\"')
    assert_parse(
      "[Script, [StringConcat, [StringPieceList, [SimpleString, a ], [StringEval, [FieldAccess, [SimpleString, b]]], [SimpleString,  c]]]]",
      '"a #@b c"')
    assert_parse(
      "[Script, [StringConcat, [StringPieceList, [SimpleString, a ], [StringEval, [FieldAccess, [SimpleString, b], static]], [SimpleString,  c]]]]",
      '"a #@@b c"')
    assert_parse(
      "[Script, [StringConcat, [StringPieceList, [SimpleString, a], [StringEval, [FunctionalCall, [SimpleString, b], [NodeList], null]], [SimpleString, c]]]]",
      '"a#{b}c"')
    assert_parse(
      "[Script, [StringConcat, [StringPieceList, [SimpleString, a], [StringEval, [SimpleString, b]], [SimpleString, c]]]]",
      '"a#{"b"}c"')
    assert_parse(
      "[Script, [StringConcat, [StringPieceList, [StringEval, null]]]]",
      '"#{}"')
    assert_fails('"')
    assert_fails('"\"')
    assert_fails('"#@"')
    assert_fails('"#{"')
  end

  def test_heredocs
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, a\n]]]]", "<<'A'\na\nA\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, ]]]]", "<<'A'\nA\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, a\n  A\n]]]]", "<<'A'\na\n  A\nA\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, a\n]]]]", "<<-'A'\na\n  A\n")
    assert_parse("[Script, [Body, [Body, [StringConcat, [StringPieceList, [SimpleString, a\n]]], [StringConcat, [StringPieceList, [SimpleString, b\n]]]], [Fixnum, 1]]]",
                 "<<'A';<<'A'\na\nA\nb\nA\n1")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, AA\n]]]]", "<<A\nAA\nA\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, a\n]]]]", "<<\"A\"\na\nA\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, a\n  A\n]]]]", "<<A\na\n  A\nA\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, a\n]]]]", "<<-A\na\n  A\n")
    assert_parse("[Script, [StringConcat, [StringPieceList, [SimpleString, ]]]]", "<<A\nA\n")
    assert_parse("[Script, [Body, [Body, [StringConcat, [StringPieceList, [SimpleString, a\n]]], [StringConcat, [StringPieceList, [SimpleString, b\n]]]], [Fixnum, 1]]]",
                 "<<A;<<A\na\nA\nb\nA\n1")
    assert_parse("[Script, [Body, [StringConcat, [StringPieceList, [StringEval, [StringConcat, [StringPieceList, [SimpleString, B\n]]]], [SimpleString, \n]]], [StringConcat, [StringPieceList, [SimpleString, b\n]]], [Constant, [SimpleString, A]]]]",
                 "<<A;<<B\n\#{<<A\nB\nA\n}\nA\nb\nB\nA\n")
    assert_fails("<<FOO")
    assert_parse("[Script, [FunctionalCall, [SimpleString, a], [NodeList, [StringConcat, [StringPieceList, [SimpleString, c\n]]]], null]]", "a <<b\nc\nb\n")
    assert_parse("[Script, [Body, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, <<], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null], [FunctionalCall, [SimpleString, c], [NodeList], null], [FunctionalCall, [SimpleString, b], [NodeList], null]]]", "a << b\nc\n b\n")
  end

  def test_regexp
    assert_parse("[Script, [Regex, [StringPieceList, [SimpleString, a]], [SimpleString, ]]]", '/a/')
    assert_parse("[Script, [Regex, [StringPieceList, [SimpleString, \\/]], [SimpleString, ]]]", '/\\//')
    assert_parse("[Script, [Regex, [StringPieceList, [SimpleString, a]], [SimpleString, i]]]", '/a/i')
    assert_parse("[Script, [Regex, [StringPieceList, [SimpleString, a]], [SimpleString, iz]]]", '/a/iz')
    assert_parse("[Script, [Regex, [StringPieceList, [SimpleString, a], [StringEval, [FunctionalCall, [SimpleString, b], [NodeList], null]], [SimpleString, c]], [SimpleString, iz]]]", '/a#{b}c/iz')
    assert_parse("[Script, [Regex, [StringPieceList], [SimpleString, ]]]", '//')
  end

  def test_begin
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2]]]", "begin; 1; 2; end")
    assert_parse("[Script, [Fixnum, 1]]", "begin; 1; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], null, [Fixnum, 2]]], null]]",
                 "begin; 1; rescue; 2; end")
    assert_parse("[Script, [Ensure, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], null, [Fixnum, 2]]], null], [Fixnum, 3]]]",
                 "begin; 1; rescue; 2; ensure 3; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], null, [Fixnum, 2]]], null]]",
                 "begin; 1; rescue then 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], null, [Fixnum, 2]]], [Fixnum, 3]]]",
                 "begin; 1; rescue then 2; else 3; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], null, [Fixnum, 2]]], null]]",
                 "begin; 1; rescue;then 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], [SimpleString, ex], [Fixnum, 2]]], null]]",
                 "begin; 1; rescue => ex; 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList], [SimpleString, ex], [Fixnum, 2]]], null]]",
                 "begin; 1; rescue => ex then 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList, [Constant, [SimpleString, A]]], null, [Fixnum, 2]]], null]]",
                 "begin; 1; rescue A; 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList, [Constant, [SimpleString, A]], [Constant, [SimpleString, B]]], null, [Fixnum, 2]]], null]]",
                 "begin; 1; rescue A, B; 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList, [Constant, [SimpleString, A]], [Constant, [SimpleString, B]]], [SimpleString, t], [Fixnum, 2]]], null]]",
                 "begin; 1; rescue A, B => t; 2; end")
    assert_parse("[Script, [Rescue, [Fixnum, 1], [RescueClauseList, [RescueClause, [TypeNameList, [Constant, [SimpleString, A]]], [SimpleString, a], [Fixnum, 2]], [RescueClause, [TypeNameList, [Constant, [SimpleString, B]]], [SimpleString, b], [Fixnum, 3]]], null]]",
                 "begin; 1; rescue A => a;2; rescue B => b; 3; end")
    assert_parse("[Script, [Body, [Fixnum, 1], [Fixnum, 2]]]", "begin; 1; else; 2; end")
  end

  def test_primary
    assert_parse("[Script, [Boolean, true]]", '(true)')
    assert_parse("[Script, [Body, [Body, [Fixnum, 1], [Fixnum, 2]], [Fixnum, 3]]]", "(1; 2);3")
    assert_parse("[Script, [Colon2, [Colon2, [Constant, [SimpleString, A]], [SimpleString, B]], [SimpleString, C]]]", 'A::B::C')
    assert_parse("[Script, [Colon2, [Colon2, [Colon3, [SimpleString, A]], [SimpleString, B]], [SimpleString, C]]]", '::A::B::C')
    assert_parse("[Script, [Array, [NodeList]]]", ' [ ]')
    assert_parse("[Script, [Array, [NodeList, [Fixnum, 1], [Fixnum, 2]]]]", ' [ 1 , 2 ]')
    assert_parse("[Script, [Array, [NodeList, [Fixnum, 1], [Fixnum, 2]]]]", ' [ 1 , 2 , ]')
    assert_parse("[Script, [Hash, null]]", ' { }')
    assert_parse("[Script, [Hash, [HashEntryList, [HashEntry, [Fixnum, 1], [Fixnum, 2]]]]]", ' { 1 => 2 }')
    assert_parse("[Script, [Hash, [HashEntryList, [HashEntry, [Fixnum, 1], [Fixnum, 2]], [HashEntry, [Fixnum, 3], [Fixnum, 4]]]]]", ' { 1 => 2 , 3 => 4 }')
    assert_parse("[Script, [Hash, [HashEntryList, [HashEntry, [SimpleString, a], [Fixnum, 2]]]]]", ' { a: 2 }')
    assert_parse("[Script, [Hash, [HashEntryList, [HashEntry, [SimpleString, a], [Fixnum, 2]], [HashEntry, [SimpleString, b], [Fixnum, 4]]]]]", ' { a: 2 , b: 4 }')
    # assert_parse("[Script, [Yield]]", 'yield')
    # assert_parse("[Script, [Yield]]", 'yield ( )')
    # assert_parse("[Script, [Yield, [Constant, [SimpleString, A]]]]", 'yield(A)')
    # assert_parse("[Script, [Yield, [Constant, [SimpleString, A]], [Constant, [SimpleString, B]]]]", 'yield (A , B)')
    # assert_parse("[Script, [Yield, [Array, [NodeList, [Constant, [SimpleString, A]], [Constant, [SimpleString, B]]]]]]", 'yield([A , B])')
    assert_parse("[Script, [Next]]", 'next')
    assert_parse("[Script, [Redo]]", 'redo')
    assert_parse("[Script, [Break]]", 'break')
    # assert_parse("[Script, [Retry]]", 'retry')
    assert_parse("[Script, [Not, [ImplicitNil]]]", '!()')
    assert_parse("[Script, [Not, [Boolean, true]]]", '!(true)')
    assert_parse("[Script, [ClassAppendSelf, [Fixnum, 1]]]", 'class << self;1;end')
    assert_parse("[Script, [ClassDefinition, [Constant, [SimpleString, A]], null, [Fixnum, 1], [TypeNameList], [AnnotationList]]]", 'class A;1;end')
    # assert_parse("[Script, [ClassDefinition, [Colon2, [Constant, [SimpleString, A]], [Constant, [SimpleString, B]]], [Fixnum, 1], [TypeNameList], [AnnotationList]]]", 'class A::B;1;end')
    assert_parse("[Script, [ClassDefinition, [Constant, [SimpleString, A]], [Constant, [SimpleString, B]], [Fixnum, 1], [TypeNameList], [AnnotationList]]]", 'class A < B;1;end')
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList], [Block, null, [FunctionalCall, [SimpleString, x], [NodeList], null]]]]", "foo do;x;end")
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList], [Block, null, [FunctionalCall, [SimpleString, y], [NodeList], null]]]]", "foo {y}")
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo?], [NodeList], [Block, null, [FunctionalCall, [SimpleString, z], [NodeList], null]]]]", "foo? {z}")
    assert_fails('class a;1;end')
  end

  def test_if
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [Fixnum, 1], null]]", 'if a then 1 end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [Fixnum, 1], null]]", 'if a;1;end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], null, null]]", 'if a;else;end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [Fixnum, 1], [Fixnum, 2]]]", 'if a then 1 else 2 end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [Fixnum, 1], [If, [FunctionalCall, [SimpleString, b], [NodeList], null], [Fixnum, 2], [Fixnum, 3]]]]",
                 'if a; 1; elsif b; 2; else; 3; end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], null, [Fixnum, 1]]]", 'unless a then 1 end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], null, [Fixnum, 1]]]", 'unless a;1;end')
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [Fixnum, 2], [Fixnum, 1]]]", 'unless a then 1 else 2 end')
    assert_fails("if;end")
    assert_fails("if a then 1 else 2 elsif b then 3 end")
    assert_fails("if a;elsif end")
  end

  def test_loop
    assert_parse("[Script, [Loop, [Body], [Boolean, true], [Body], [Body, [ImplicitNil]], [Body]]]", 'while true do end')
    assert_parse("[Script, [Loop, [Body], [FunctionalCall, [SimpleString, a], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Body]]]", 'while a do b end')
    assert_parse("[Script, [Loop, [Body], [FunctionalCall, [SimpleString, a], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Body]]]", 'while a; b; end')
    assert_parse("[Script, [Loop, negative, [Body], [Boolean, true], [Body], [Body, [ImplicitNil]], [Body]]]", 'until true do end')
    assert_parse("[Script, [Loop, negative, [Body], [FunctionalCall, [SimpleString, a], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Body]]]", 'until a do b end')
    assert_parse("[Script, [Loop, negative, [Body], [FunctionalCall, [SimpleString, a], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Body]]]", 'until a; b; end')
    assert_parse("[Script, [Call, [Array, [NodeList, [Fixnum, 1]]], [SimpleString, each], [NodeList], [Block, [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], [Fixnum, 2]]]]", 'for a in [1];2;end')
  end

  def test_def
    names = %w(foo bar? baz! def= rescue Class & | ^ < > + - * / % ! ~ <=> ==
               === =~ !~ <= >= << <<< >> != ** []= [] +@ -@)
    names.each do |name|
      assert_parse("[Script, [MethodDefinition, [SimpleString, #{name}], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                   "def #{name}; 1; end")
      assert_parse("[Script, [StaticMethodDefinition, [SimpleString, #{name}], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                   "def self.#{name}; 1; end")
    end
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 2], [AnnotationList]]]",
                 "def foo(a); 2; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo a; 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], [Constant, [SimpleString, SimpleString]]]], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a:SimpleString); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null], [RequiredArgument, [SimpleString, b], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a, b); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList, [OptionalArgument, [SimpleString, a], null, [Fixnum, 1]]], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a = 1); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList, [OptionalArgument, [SimpleString, a], [SimpleString, int], [Fixnum, 1]]], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a:int = 1); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList, [OptionalArgument, [SimpleString, a], null, [Fixnum, 1]], [OptionalArgument, [SimpleString, b], null, [Fixnum, 2]]], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a = 1, b=2); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], [RestArgument, null, null], [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(*); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], [RestArgument, [SimpleString, a], null], [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(*a); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], [RestArgument, [SimpleString, a], [Constant, [SimpleString, Object]]], [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(*a:Object); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], [BlockArgument, [SimpleString, a], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(&a); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], [BlockArgument, optional, [SimpleString, a], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(&a = nil); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList, [OptionalArgument, [SimpleString, b], null, [Fixnum, 1]]], [RestArgument, [SimpleString, c], null], [RequiredArgumentList, [RequiredArgument, [SimpleString, d], null]], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a, b=1, *c, d, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList], [RestArgument, [SimpleString, c], null], [RequiredArgumentList, [RequiredArgument, [SimpleString, d], null]], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a, *c, d, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList, [OptionalArgument, [SimpleString, b], null, [Fixnum, 1]]], null, [RequiredArgumentList, [RequiredArgument, [SimpleString, d], null]], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a, b=1, d, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList, [OptionalArgument, [SimpleString, b], null, [Fixnum, 1]]], [RestArgument, [SimpleString, c], null], [RequiredArgumentList], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a, b=1, *c, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList, [OptionalArgument, [SimpleString, b], null, [Fixnum, 1]]], [RestArgument, [SimpleString, c], null], [RequiredArgumentList, [RequiredArgument, [SimpleString, d], null]], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(b=1, *c, d, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList, [OptionalArgument, [SimpleString, b], null, [Fixnum, 1]]], null, [RequiredArgumentList, [RequiredArgument, [SimpleString, d], null]], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(b=1, d, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList, [OptionalArgument, [SimpleString, b], null, [Fixnum, 1]]], [RestArgument, [SimpleString, c], null], [RequiredArgumentList], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(b=1, *c, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], [RestArgument, [SimpleString, c], null], [RequiredArgumentList, [RequiredArgument, [SimpleString, d], null]], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(*c, d, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], [RestArgument, [SimpleString, c], null], [RequiredArgumentList], [BlockArgument, [SimpleString, e], null]], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(*c, &e); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], [SimpleString, int], [Fixnum, 1], [AnnotationList]]]",
                 "def foo(a):int; 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, bar], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], [SimpleString, int], [Fixnum, 1], [AnnotationList]]]",
                 "def bar:int; 1; end")
    assert_fails("def foo(*a, *b);end")
    assert_fails("def foo(&a, &b);end")
    assert_fails("def foo(&a=1);end")
  end

  def test_method_call
    assert_parse("[Script, [FunctionalCall, [SimpleString, B], [NodeList], null]]", 'B()')
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, a], [NodeList], null]], null]]", 'foo(a)')
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, a], [NodeList], null], [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", 'foo(a, b)')
    # assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [[FunctionalCall, [SimpleString, a], [NodeList], null], [Splat, [FunctionalCall, [SimpleString, b], [NodeList], null]]], null]]", 'foo(a, *b)')
    # assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [[FunctionalCall, [SimpleString, a], [NodeList], null], [Splat, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Hash, [HashEntryList, [HashEntry, [SimpleString, c], [FunctionalCall, [SimpleString, d], [NodeList], null]]]], null]]", 'foo(a, *b, c:d)')
    # assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [[FunctionalCall, [SimpleString, a], [NodeList], null], [Splat, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Hash, [HashEntryList, [HashEntry, [SimpleString, c], [FunctionalCall, [SimpleString, d], [NodeList], null]]]], null]]", 'foo(a, *b, :c => d)')
    # assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [[FunctionalCall, [SimpleString, a], [NodeList], null], [Splat, [FunctionalCall, [SimpleString, b], [NodeList], null]], [Hash, [HashEntryList, [HashEntry, [SimpleString, c], [FunctionalCall, [SimpleString, d], [NodeList], null]]], [BlockPass, [FunctionalCall, [SimpleString, e], [NodeList], null]]], null]]", 'foo(a, *b, c:d, &e)')
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList, [Hash, [HashEntryList, [HashEntry, [SimpleString, c], [FunctionalCall, [SimpleString, d], [NodeList], null]]]]], null]]", 'foo(c:d)')
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList, [Hash, [HashEntryList, [HashEntry, [SimpleString, c], [FunctionalCall, [SimpleString, d], [NodeList], null]]]], [BlockPass, [FunctionalCall, [SimpleString, e], [NodeList], null]]], null]]", 'foo(c:d, &e)')
    assert_parse("[Script, [FunctionalCall, [SimpleString, foo], [NodeList, [BlockPass, [FunctionalCall, [SimpleString, e], [NodeList], null]]], null]]", 'foo(&e)')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, foo], [NodeList], null]]", 'a.foo')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, foo], [NodeList], null]]", 'a.foo()')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, Foo], [NodeList], null]]", 'a.Foo()')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, <=>], [NodeList], null]]", 'a.<=>')
    assert_parse("[Script, [Call, [Constant, [SimpleString, Foo]], [SimpleString, Bar], [NodeList, [FunctionalCall, [SimpleString, x], [NodeList], null]], null]]", 'Foo::Bar(x)')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, call], [NodeList], null]]", 'a.()')
    assert_parse("[Script, [Call, [Constant, [SimpleString, System]], [SimpleString, in], [NodeList], null]]", "System.in")
    assert_parse("[Script, [Call, [Array, [NodeList, [FunctionalCall, [SimpleString, la], [NodeList], null], [FunctionalCall, [SimpleString, lb], [NodeList], null]]], [SimpleString, each], [NodeList], null]]", "[la, lb].each")
    assert_parse("[Script, [Call, [Constant, [SimpleString, TreeNode]], [SimpleString, bottomUpTree], [NodeList, [Call, [Fixnum, 2], [SimpleString, *], [NodeList, [FunctionalCall, [SimpleString, item], [NodeList], null]], null], [Call, [FunctionalCall, [SimpleString, depth], [NodeList], null], [SimpleString, -], [NodeList, [Fixnum, 1]], null]], null]]", "TreeNode.bottomUpTree(2*item, depth-1)")
    assert_parse("[Script, [FunctionalCall, [SimpleString, iterate], [NodeList, [Call, [FunctionalCall, [SimpleString, x], [NodeList], null], [SimpleString, /], [NodeList, [Float, 40.0]], null], [Call, [FunctionalCall, [SimpleString, y], [NodeList], null], [SimpleString, /], [NodeList, [Float, 40.0]], null]], null]]", "iterate(x/40.0,y/40.0)")
    assert_parse("[Script, [Super, [NodeList], null]]", 'super()')
    assert_parse("[Script, [ZSuper]]", 'super')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, foo], [NodeList], null]]", "a\n.\nfoo")
  end

  def test_command
    assert_parse("[Script, [FunctionalCall, [SimpleString, A], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", 'A b')
    assert_parse("[Script, [Call, [Constant, [SimpleString, Foo]], [SimpleString, Bar], [NodeList, [FunctionalCall, [SimpleString, x], [NodeList], null]], null]]", 'Foo::Bar x')
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, foo], [NodeList], null], [SimpleString, bar], [NodeList, [FunctionalCall, [SimpleString, x], [NodeList], null]], null]]", 'foo.bar x')
    assert_parse("[Script, [Super, [NodeList, [FunctionalCall, [SimpleString, x], [NodeList], null]]]]", 'super x')
    assert_parse("[Script, [Yield, [NodeList, [FunctionalCall, [SimpleString, x], [NodeList], null]]]]", 'yield x')
    assert_parse("[Script, [Return, [FunctionalCall, [SimpleString, x], [NodeList], null]]]", 'return x')
    assert_parse("[Script, [FunctionalCall, [SimpleString, a], [NodeList, [CharLiteral, 97]], null]]", 'a ?a')
    # assert_parse("[Script, [FunctionalCall, [SimpleString, a], [[Splat, [FunctionalCall, [SimpleString, b], [NodeList], null]]], null]]", 'a *b')
  end

  def test_lhs
    assert_parse("[Script, [LocalAssignment, [SimpleString, a], [FunctionalCall, [SimpleString, b], [NodeList], null]]]", "a = b")
    assert_parse("[Script, [ConstantAssign, [SimpleString, A], [FunctionalCall, [SimpleString, b], [NodeList], null], [AnnotationList]]]", "A = b")
    assert_parse("[Script, [FieldAssign, [SimpleString, a], [FunctionalCall, [SimpleString, b], [NodeList], null], [AnnotationList]]]", "@a = b")
    assert_parse("[Script, [FieldAssign, [SimpleString, a], [FunctionalCall, [SimpleString, b], [NodeList], null], [AnnotationList], static]]", "@@a = b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, []=], [NodeList, [Fixnum, 0], [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a[0] = b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, foo=], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a.foo = b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, foo=], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a::foo = b")
    assert_fails("a::Foo = b")
    assert_fails("::Foo = b")
  end

  def test_arg
    assert_parse("[Script, [LocalAssignment, [SimpleString, a], [Rescue, [FunctionalCall, [SimpleString, b], [NodeList], null], [RescueClauseList, [RescueClause, [TypeNameList], null, [FunctionalCall, [SimpleString, c], [NodeList], null]]], null]]]",
                 "a = b rescue c")
    assert_parse("[Script, [If, [LocalAccess, [SimpleString, a]], [LocalAssignment, [SimpleString, a], [FunctionalCall, [SimpleString, b], [NodeList], null]], [LocalAccess, [SimpleString, a]]]]",
                 "a &&= b")
    assert_parse("[Script, [If, [LocalAccess, [SimpleString, a]], [LocalAccess, [SimpleString, a]], [LocalAssignment, [SimpleString, a], [FunctionalCall, [SimpleString, b], [NodeList], null]]]]",
                 "a ||= b")
    assert_parse("[Script, [FieldAssign, [SimpleString, a], [Call, [FieldAccess, [SimpleString, a]], [SimpleString, +], [NodeList, [Fixnum, 1]], null], [AnnotationList]]]",
                 "@a += 1")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [LocalAssignment, [SimpleString, $ptemp$2], [Fixnum, 1]]," +
                                " [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, []=], [NodeList, [LocalAccess, [SimpleString, $ptemp$2]], [Call, [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, []], [NodeList, [LocalAccess, [SimpleString, $ptemp$2]]], null], [SimpleString, -], [NodeList, [Fixnum, 2]], null]], null]]]",
                 "a[1] -= 2")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [If, [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo], [NodeList], null]," +
                                      " [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo=], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null], null]]]",
                 "a.foo &&= b")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [Body, [LocalAssignment, [SimpleString, $or$2], [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo], [NodeList], null]], [If, [SimpleString, $or$2], [SimpleString, $or$2], [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo=], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]]]]",
                 "a::foo ||= b")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, Foo=], [NodeList," +
                                             " [Call, [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, Foo], [NodeList], null], [SimpleString, &], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]], null" +
                                "]]]",
                 "a.Foo &= b")
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [FunctionalCall, [SimpleString, b], [NodeList], null], [FunctionalCall, [SimpleString, c], [NodeList], null]]]",
                 "a ? b : c")
    # TODO operators need a ton more testing
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, +], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a + b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, -], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a - b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, *], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a * b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, *], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null]]", "a*b")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, <], [NodeList, [Fixnum, -1]], null]]", "a < -1")
    assert_parse("[Script, [Fixnum, -1]]", "-1")
    assert_parse("[Script, [Float, -1.0]]", "-1.0")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, -@], [NodeList], null]]", "-a")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, +@], [NodeList], null]]", "+a")

    assert_parse("[Script, [Call, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [SimpleString, -], [NodeList, [FunctionalCall, [SimpleString, b], [NodeList], null]], null], [SimpleString, +], [NodeList, [FunctionalCall, [SimpleString, c], [NodeList], null]], null]]",
                 "a - b + c")

    assert_fails("::A ||= 1")
    assert_fails("A::B ||= 1")
   end

   def test_expr
    assert_parse("[Script, [If, [LocalAssignment, [SimpleString, a], [Fixnum, 1]], [LocalAssignment, [SimpleString, b], [Fixnum, 2]], null]]",
                 "a = 1 and b = 2")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $or$1], [LocalAssignment, [SimpleString, a], [Fixnum, 1]]], [If, [SimpleString, $or$1], [SimpleString, $or$1], [LocalAssignment, [SimpleString, b], [Fixnum, 2]]]]]",
                 "a = 1 or b = 2")
    assert_parse("[Script, [Not, [LocalAssignment, [SimpleString, a], [Fixnum, 1]]]]",
                 "not a = 1")
    assert_parse("[Script, [Not, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]]]",
                 "! foo bar")
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, a], [NodeList], null], [Call, [FunctionalCall, [SimpleString, x], [NodeList], null], [SimpleString, children], [NodeList], null], [Array, [NodeList, [FunctionalCall, [SimpleString, x], [NodeList], null]]]]]", "a ? x.children : [x]")
   end

   def test_stmt
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, b], [NodeList], null], [FunctionalCall, [SimpleString, a], [NodeList], null], null]]", "a if b")
    assert_parse("[Script, [If, [FunctionalCall, [SimpleString, b], [NodeList], null], null, [FunctionalCall, [SimpleString, a], [NodeList], null]]]", "a unless b")
    assert_parse("[Script, [Loop, [Body], [FunctionalCall, [SimpleString, b], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Body]]]", "a while b")
    assert_parse("[Script, [Loop, negative, [Body], [FunctionalCall, [SimpleString, b], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Body]]]", "a until b")
    assert_parse("[Script, [Loop, skipFirstCheck, [Body], [FunctionalCall, [SimpleString, b], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Body]]]", "begin;a;end while b")
    assert_parse("[Script, [Loop, skipFirstCheck, negative, [Body], [FunctionalCall, [SimpleString, b], [NodeList], null], [Body], [Body, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Body]]]", "begin;a;end until b")
    assert_parse("[Script, [Rescue, [FunctionalCall, [SimpleString, a], [NodeList], null], [RescueClauseList, [RescueClause, [TypeNameList], null, [FunctionalCall, [SimpleString, b], [NodeList], null]]], null]]",
                 "a rescue b")
    assert_parse("[Script, [LocalAssignment, [SimpleString, a], [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]]]", "a = foo bar")
    assert_parse("[Script, [LocalAssignment, [SimpleString, a], [Call, [LocalAccess, [SimpleString, a]], [SimpleString, +], [NodeList, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]], null]]]", "a += foo bar")
    assert_parse("[Script, [If, [LocalAccess, [SimpleString, a]], [LocalAssignment, [SimpleString, a], [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]], [LocalAccess, [SimpleString, a]]]]",
                 "a &&= foo bar")
    assert_parse("[Script, [If, [LocalAccess, [SimpleString, a]], [LocalAccess, [SimpleString, a]], [LocalAssignment, [SimpleString, a], [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]]]]",
                 "a ||= foo bar")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [LocalAssignment, [SimpleString, $ptemp$2], [Fixnum, 1]]," +
                                " [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, []=], [NodeList, [LocalAccess, [SimpleString, $ptemp$2]], [Call, [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, []], [NodeList, [LocalAccess, [SimpleString, $ptemp$2]]], null], [SimpleString, -], [NodeList, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]], null]], null]]]",
                 "a[1] -= foo bar")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [If, [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo], [NodeList], null]," +
                                      " [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo=], [NodeList, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]], null], null]" +
                                "]]",
                 "a.foo &&= foo bar")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [Body, [LocalAssignment, [SimpleString, $or$2], [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo], [NodeList], null]], [If, [SimpleString, $or$2], [SimpleString, $or$2], [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, foo=], [NodeList, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]], null]]]]]",
                 "a::foo ||= foo bar")
    assert_parse("[Script, [Body, [LocalAssignment, [SimpleString, $ptemp$1], [FunctionalCall, [SimpleString, a], [NodeList], null]]," +
                                " [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, Foo=], [NodeList," +
                                             " [Call, [Call, [LocalAccess, [SimpleString, $ptemp$1]], [SimpleString, Foo], [NodeList], null], [SimpleString, &], [NodeList, [FunctionalCall, [SimpleString, foo], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]], null]], null" +
                                "]]]",
                 "a.Foo &= foo bar")
   end

   def test_block_args
     assert_parse("[Script, [FunctionalCall, [SimpleString, a], [NodeList], [Block, [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, x], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], [FunctionalCall, [SimpleString, x], [NodeList], null]]]]", "a {|x| x}")
     assert_parse("[Script, [FunctionalCall, [SimpleString, a], [NodeList], [Block, [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], [FunctionalCall, [SimpleString, x], [NodeList], null]]]]", "a {|| x}")
   end

   def test_block_call
     assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], [Block, null, [FunctionalCall, [SimpleString, b], [NodeList], null]]], [SimpleString, c], [NodeList], null]]", "a do;b;end.c")
     assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], [Block, null, [FunctionalCall, [SimpleString, b], [NodeList], null]]], [SimpleString, c], [NodeList], null]]", "a {b}.c")
     assert_parse("[Script, [Super, [NodeList, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Block, null, [FunctionalCall, [SimpleString, b], [NodeList], null]]]]", "super a do;b;end")
     assert_parse("[Script, [Super, [NodeList, [Call, [FunctionalCall, [SimpleString, a], [NodeList], [Block, null, [FunctionalCall, [SimpleString, b], [NodeList], null]]], [SimpleString, c], [NodeList], null]], null]]", "super a {b}.c")
     assert_parse("[Script, [Call, [Super, [NodeList, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Block, null, [FunctionalCall, [SimpleString, b], [NodeList], null]]], [SimpleString, c], [NodeList], null]]", "super a do;b;end.c")
   end

   def test_opt_nl
     assert_parse("[Script, [Hash, [HashEntryList, [HashEntry, [SimpleString, a], [SimpleString, b]], [HashEntry, [SimpleString, c], [FunctionalCall, [SimpleString, d], [NodeList], null]]]]]",
                  "{\n'a' => 'b', c:\nd\n}")
   end

   def test_ne
     assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, foo], [NodeList], null], [SimpleString, !=], [NodeList, [FunctionalCall, [SimpleString, bar], [NodeList], null]], null]]", "foo!=bar")
   end

   def test_command
     assert_parse("[Script, [ImplicitNil]]", "begin  # hi\nend")
   end

   def test_macros
     assert_parse("[Script, [Unquote, [FunctionalCall, [SimpleString, x], [NodeList], null]]]", '`x`')
     assert_parse("[Script, [ClassDefinition, [Unquote, [Constant, [SimpleString, A]]], null, [Fixnum, 1], [TypeNameList], [AnnotationList]]]", 'class `A`;1;end')
     assert_parse("[Script, [MethodDefinition, [Unquote, [FunctionalCall, [SimpleString, foo], [NodeList], null]], [Arguments, [RequiredArgumentList, [RequiredArgument, [SimpleString, a], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                  "def `foo`(a); 1; end")
    assert_parse("[Script, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList, [RequiredArgument, [Unquote, [FunctionalCall, [SimpleString, a], [NodeList], null]], null]], [OptionalArgumentList], null, [RequiredArgumentList], null], null, [Fixnum, 1], [AnnotationList]]]",
                 "def foo(`a`); 1; end")
    assert_parse("[Script, [Call, [FunctionalCall, [SimpleString, a], [NodeList], null], [Unquote, [FunctionalCall, [SimpleString, foo], [NodeList], null]], [NodeList], null]]", 'a.`foo`')
    assert_parse("[Script, [Call, [Self], [Unquote, [FunctionalCall, [SimpleString, foo], [NodeList], null]], [NodeList], null]]", 'self.`foo`')
    assert_parse("[Script, [FieldAccess, [Unquote, [FunctionalCall, [SimpleString, a], [NodeList], null]]]]", "@`a`")
    assert_parse("[Script, [FieldAssign, [Unquote, [FunctionalCall, [SimpleString, a], [NodeList], null]], [Fixnum, 1], [AnnotationList]]]", "@`a` = 1")
    assert_parse("[Script, [UnquoteAssign, [Unquote, [FunctionalCall, [SimpleString, a], [NodeList], null]], [FunctionalCall, [SimpleString, b], [NodeList], null]]]", "`a` = b")
    assert_parse("[Script, [FunctionalCall, [SimpleString, macro], [NodeList, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], null," +
                                               " [FunctionalCall, [SimpleString, quote], [NodeList], [Block, null, [FunctionalCall, [SimpleString, bar], [NodeList], null]]], [AnnotationList]]], null]]",
                 "macro def foo; quote {bar}; end")
    assert_parse("[Script, [FunctionalCall, [SimpleString, macro], [NodeList, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], null," +
                                               " [FunctionalCall, [SimpleString, quote], [NodeList], [Block, null, [FunctionalCall, [SimpleString, bar], [NodeList], null]]], [AnnotationList]]], null]]",
                 "macro def foo; quote do bar end; end")
    assert_parse("[Script, [FunctionalCall, [SimpleString, macro], [NodeList, [MethodDefinition, [SimpleString, foo], [Arguments, [RequiredArgumentList], [OptionalArgumentList], null, [RequiredArgumentList], null], null," +
                                               " [Body, [FunctionalCall, [SimpleString, bar], [NodeList], null]," +
                                                      " [FunctionalCall, [SimpleString, quote], [NodeList], [Block, null, [FunctionalCall, [SimpleString, baz], [NodeList], null]]]], [AnnotationList]]], null]]",
                 "macro def foo; bar; quote do baz end; end")
   end

   def test_annotation
     assert_parse("[Script, [Annotation, [Constant, [SimpleString, Foo]], null]]", "$Foo")
     assert_parse("[Script, [Annotation, [Constant, [SimpleString, Foo]], [Hash, [HashEntryList, [HashEntry, [SimpleString, value], [Constant, [SimpleString, Bar]]]]]]]", "$Foo[Bar]")
     assert_parse("[Script, [Annotation, [Constant, [SimpleString, Foo]], [Hash, [HashEntryList, [HashEntry, [SimpleString, foo], [Constant, [SimpleString, Bar]]]]]]]", "$Foo[foo: Bar]")
   end

   def test_return
     assert_parse("[Script, [Return, [Fixnum, -1]]]", "return -1")
     assert_parse("[Script, [Return, [Fixnum, -1]]]", "return (-1)")
     assert_parse("[Script, [Return, [ImplicitNil]]]", "return")
   end

   def test_call_assocs
    assert_parse("[Script, [FunctionalCall, [SimpleString, puts], [NodeList, [Hash, [HashEntryList, [HashEntry, [SimpleString, a], [SimpleString, b]]]]], null]]", "puts :a => :b")
   end

   def test_block_comment
     assert_parse("[Script, [Fixnum, 3]]", "/* A /* nested */ comment */3")
   end

   def test_assign_nl
     assert_parse("[Script, [LocalAssignment, [SimpleString, a], [Fixnum, 1]]]", "a =\n   1")
     assert_parse("[Script, [LocalAssignment, [SimpleString, html], [Call, [LocalAccess, [SimpleString, html]], [SimpleString, +], [NodeList, [SimpleString, ]], null]]]", " html += \n ''")
   end
end
