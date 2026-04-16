# frozen_string_literal: true

require_relative "test_helper"

class LexerTest < Minitest::Test
  def test_numbers
    tokens = lex("42 3.14")
    assert_token tokens[0], :number, 42
    assert_token tokens[1], :number, 3.14
  end

  def test_strings
    tokens = lex('"hello world"')
    assert_token tokens[0], :string, "hello world"
  end

  def test_string_escape_sequences
    tokens = lex('"line1\\nline2\\ttab"')
    assert_token tokens[0], :string, "line1\nline2\ttab"
  end

  def test_unterminated_string_raises
    assert_raises(Crux::SyntaxError) { lex('"oops') }
  end

  def test_identifiers_and_keywords
    tokens = lex("let x = fn if then else end do while and or not true false nil")
    types = tokens.map(&:type)
    assert_equal %i[let identifier equal fn if then else end do while and or not true false nil eof], types
  end

  def test_operators
    tokens = lex("+ - * / % == != < > <= >= |> ->")
    types = tokens.map(&:type)
    assert_equal %i[plus minus star slash percent equal_equal bang_equal less greater less_equal greater_equal pipe arrow eof], types
  end

  def test_comments_are_skipped
    tokens = lex("42 # this is a comment\n7")
    assert_token tokens[0], :number, 42
    assert_token tokens[1], :newline, "\n"
    assert_token tokens[2], :number, 7
  end

  def test_consecutive_newlines_collapse
    tokens = lex("1\n\n\n2")
    types = tokens.map(&:type)
    assert_equal %i[number newline number eof], types
  end

  def test_semicolons_as_separators
    tokens = lex("1; 2; 3")
    types = tokens.map(&:type)
    assert_equal %i[number newline number newline number eof], types
  end

  def test_line_and_column_tracking
    tokens = lex("let x = 42")
    assert_equal 1, tokens[0].line
    assert_equal 1, tokens[0].column
    assert_equal 1, tokens[3].line
    assert_equal 9, tokens[3].column
  end

  def test_multiline_tracking
    tokens = lex("x\ny")
    assert_equal 1, tokens[0].line
    assert_equal 2, tokens[2].line
  end

  def test_unexpected_character_raises
    assert_raises(Crux::SyntaxError) { lex("@") }
  end

  private

  def lex(source)
    Crux::Lexer.new(source).tokenize
  end

  def assert_token(token, type, value)
    assert_equal type, token.type, "Expected token type #{type}, got #{token.type}"
    assert_equal value, token.value, "Expected token value #{value.inspect}, got #{token.value.inspect}"
  end
end
