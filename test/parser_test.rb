# frozen_string_literal: true

require_relative "test_helper"

class ParserTest < Minitest::Test
  def test_number_literal
    ast = parse("42")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::NumberLit, stmt
    assert_equal 42, stmt.value
  end

  def test_string_literal
    ast = parse('"hello"')
    stmt = ast.statements.first
    assert_instance_of Crux::AST::StringLit, stmt
    assert_equal "hello", stmt.value
  end

  def test_boolean_literals
    ast = parse("true")
    assert_instance_of Crux::AST::BoolLit, ast.statements.first
    assert_equal true, ast.statements.first.value
  end

  def test_nil_literal
    ast = parse("nil")
    assert_instance_of Crux::AST::NilLit, ast.statements.first
  end

  def test_let_binding
    ast = parse("let x = 42")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::LetBinding, stmt
    assert_equal "x", stmt.name
    assert_instance_of Crux::AST::NumberLit, stmt.value
  end

  def test_binary_arithmetic
    ast = parse("1 + 2 * 3")
    # Should parse as 1 + (2 * 3) due to precedence
    stmt = ast.statements.first
    assert_instance_of Crux::AST::BinaryOp, stmt
    assert_equal :plus, stmt.operator
    assert_instance_of Crux::AST::NumberLit, stmt.left
    assert_instance_of Crux::AST::BinaryOp, stmt.right
    assert_equal :star, stmt.right.operator
  end

  def test_unary_minus
    ast = parse("-42")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::UnaryOp, stmt
    assert_equal :minus, stmt.operator
  end

  def test_logical_operators
    ast = parse("true and false or true")
    # Should parse as (true and false) or true
    stmt = ast.statements.first
    assert_instance_of Crux::AST::BinaryOp, stmt
    assert_equal :or, stmt.operator
  end

  def test_function_literal
    ast = parse("fn(x, y) -> x + y")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::Function, stmt
    assert_equal ["x", "y"], stmt.params
    assert_instance_of Crux::AST::BinaryOp, stmt.body
  end

  def test_function_call
    ast = parse("add(1, 2)")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::Call, stmt
    assert_equal 2, stmt.arguments.length
  end

  def test_if_expression
    ast = parse("if true then 1 else 2 end")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::If, stmt
    assert_instance_of Crux::AST::NumberLit, stmt.then_branch
    assert_instance_of Crux::AST::NumberLit, stmt.else_branch
  end

  def test_if_without_else
    ast = parse("if true then 1 end")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::If, stmt
    assert_nil stmt.else_branch
  end

  def test_while_loop
    ast = parse("while true do 1 end")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::While, stmt
  end

  def test_pipe_expression
    ast = parse("5 |> double")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::Pipe, stmt
    assert_instance_of Crux::AST::NumberLit, stmt.value
    assert_instance_of Crux::AST::Identifier, stmt.function
  end

  def test_chained_pipes
    ast = parse("5 |> double |> print")
    stmt = ast.statements.first
    # Pipes are left-associative: (5 |> double) |> print
    assert_instance_of Crux::AST::Pipe, stmt
    assert_instance_of Crux::AST::Pipe, stmt.value
  end

  def test_block
    ast = parse("do\n  let x = 1\n  x + 1\nend")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::Block, stmt
    assert_equal 2, stmt.statements.length
  end

  def test_grouped_expression
    ast = parse("(1 + 2) * 3")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::BinaryOp, stmt
    assert_equal :star, stmt.operator
    assert_instance_of Crux::AST::BinaryOp, stmt.left
  end

  def test_assignment
    ast = parse("x = 42")
    stmt = ast.statements.first
    assert_instance_of Crux::AST::Assignment, stmt
    assert_equal "x", stmt.name
  end

  def test_multiple_statements
    ast = parse("let x = 1\nlet y = 2")
    assert_equal 2, ast.statements.length
  end

  private

  def parse(source)
    tokens = Crux::Lexer.new(source).tokenize
    Crux::Parser.new(tokens).parse
  end
end
