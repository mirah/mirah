require 'test/unit'
require 'java'

$CLASSPATH << 'dist/mirah-parser.jar'

class TestLexer < Test::Unit::TestCase
  java_import 'mirah.impl.MirahLexer'
  java_import 'mirah.lang.ast.StringCodeSource'
  java_import 'mirah.impl.MirahParser'
  java_import 'mirah.impl.Tokens'
  java_import 'org.mirah.mmeta.SyntaxError'

  def parse(text, ignore_spaces, ignore_comments)
    parser = MirahParser.new
    parser.init(text)
    lexer = MirahLexer.new parser._string, parser._chars , parser
    result = []
    pos = 0
    while (token = lexer.lex(pos, ignore_spaces, ignore_comments)).type != Tokens::tEOF
      result << token
      pos = token.endpos
    end
    result.join(",")
  end

  def assert_parse(expected, text , ignore_spaces, ignore_comments)
    tokens = parse(text, ignore_spaces, ignore_comments)
    assert_equal(expected, tokens, "expected '#{text}' to be converted ignore spaces: #{ignore_spaces}, #{ignore_comments} " )
  end

  def assert_fails(text)
    begin
      fail("Should raise syntax error, but got #{parse text, true, true}")
    rescue SyntaxError
      # ok
    end
  end

  def test_javadoc_whitespace_removal
    assert_parse('<Token tClass: \'class\'>,<Token tCONSTANT: \'X\'>,<Token tSemi: \';\'>,<Token tEnd: \'end\'>', 'class X; end', true, true)
    assert_parse('', ' #class X; end', true, true)
    assert_parse('', ' /** jdoc */ ', true, true)
    assert_fails('/*not finished ')

    assert_parse(%q{<Token tClass: 'class'>,<Token tWhitespace: ' '>,<Token tCONSTANT: 'X'>,<Token tSemi: ';'>,<Token tWhitespace: ' '>,<Token tEnd: 'end'>}, 'class X; end', false, false)
    assert_parse(%q{<Token tWhitespace: ' '>,<Token tComment: '#class X; end '>}, ' #class X; end ', false, false)

    # TODO figure out why this fails
    #assert_parse(%q{<Token tWhitespace: ' '>,<Token tJavaDoc: '/** jdoc */'>,<Token tWhitespace: ' '>}, ' /** jdoc */ ', false ,false)
    #assert_parse(%q{<Token tJavaDoc: '/** jdoc */'>}, ' /** jdoc */ ', true, false)

    assert_parse(%q{<Token tClass: 'class'>,<Token tCONSTANT: 'X'>,<Token tSemi: ';'>,<Token tEnd: 'end'>}, 'class X; end', true, false)
    assert_parse('', ' #class X; end ', true, false)
    

  end
end
