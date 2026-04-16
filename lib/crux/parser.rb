# frozen_string_literal: true

module Crux
  # Recursive-descent parser that transforms a token stream into an AST.
  #
  # Grammar (simplified):
  #
  #   program    := statement (NEWLINE statement)* EOF
  #   statement  := let_stmt | expr_stmt
  #   let_stmt   := "let" IDENT "=" expression
  #   expr_stmt  := expression
  #   expression := pipe
  #   pipe       := assignment ("|>" call_expr)*
  #   assignment := IDENT "=" assignment | logic_or
  #   logic_or   := logic_and ("or" logic_and)*
  #   logic_and  := equality ("and" equality)*
  #   equality   := comparison (("==" | "!=") comparison)*
  #   comparison := addition (("<" | ">" | "<=" | ">=") addition)*
  #   addition   := multiply (("+" | "-") multiply)*
  #   multiply   := unary (("*" | "/" | "%") unary)*
  #   unary      := ("-" | "not") unary | call
  #   call       := primary ("(" arguments? ")")*
  #   primary    := NUMBER | STRING | "true" | "false" | "nil"
  #              |  IDENT | "(" expression ")" | fn_expr | if_expr
  #              |  while_expr | block
  class Parser
    # tokens - An Array of Token from the Lexer.
    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    # Parse the full token stream into a Program AST node.
    #
    # Returns an AST::Program.
    # Raises Crux::SyntaxError on invalid syntax.
    def parse
      skip_newlines
      stmts = []
      until check(:eof)
        stmts << parse_statement
        skip_newlines
      end
      AST::Program.new(statements: stmts)
    end

    private

    # -- Statements --------------------------------------------------------

    def parse_statement
      if check(:let)
        parse_let
      else
        parse_expression
      end
    end

    def parse_let
      consume(:let, "Expected 'let'")
      name = consume(:identifier, "Expected variable name after 'let'").value
      consume(:equal, "Expected '=' after variable name")
      value = parse_expression
      AST::LetBinding.new(name: name, value: value)
    end

    # -- Expressions (precedence climbing) ---------------------------------

    def parse_expression
      parse_pipe
    end

    def parse_pipe
      expr = parse_assignment

      while match(:pipe)
        func = parse_primary
        args = []
        if match(:lparen)
          args = parse_arguments unless check(:rparen)
          consume(:rparen, "Expected ')' after pipe arguments")
        end
        expr = AST::Pipe.new(value: expr, function: func, arguments: args)
      end

      expr
    end

    def parse_assignment
      expr = parse_logic_or

      if expr.is_a?(AST::Identifier) && match(:equal)
        value = parse_expression
        return AST::Assignment.new(name: expr.name, value: value)
      end

      expr
    end

    def parse_logic_or
      left = parse_logic_and
      while match(:or)
        right = parse_logic_and
        left = AST::BinaryOp.new(operator: :or, left: left, right: right)
      end
      left
    end

    def parse_logic_and
      left = parse_equality
      while match(:and)
        right = parse_equality
        left = AST::BinaryOp.new(operator: :and, left: left, right: right)
      end
      left
    end

    def parse_equality
      left = parse_comparison
      while (op = match(:equal_equal, :bang_equal))
        right = parse_comparison
        left = AST::BinaryOp.new(operator: op.type, left: left, right: right)
      end
      left
    end

    def parse_comparison
      left = parse_addition
      while (op = match(:less, :greater, :less_equal, :greater_equal))
        right = parse_addition
        left = AST::BinaryOp.new(operator: op.type, left: left, right: right)
      end
      left
    end

    def parse_addition
      left = parse_multiply
      while (op = match(:plus, :minus))
        right = parse_multiply
        left = AST::BinaryOp.new(operator: op.type, left: left, right: right)
      end
      left
    end

    def parse_multiply
      left = parse_unary
      while (op = match(:star, :slash, :percent))
        right = parse_unary
        left = AST::BinaryOp.new(operator: op.type, left: left, right: right)
      end
      left
    end

    def parse_unary
      if match(:minus)
        AST::UnaryOp.new(operator: :minus, operand: parse_unary)
      elsif match(:not)
        AST::UnaryOp.new(operator: :not, operand: parse_unary)
      else
        parse_call
      end
    end

    def parse_call
      expr = parse_primary

      while check(:lparen)
        advance
        args = check(:rparen) ? [] : parse_arguments
        consume(:rparen, "Expected ')' after arguments")
        expr = AST::Call.new(callee: expr, arguments: args)
      end

      expr
    end

    # -- Primary -----------------------------------------------------------

    def parse_primary
      if check(:number) || check(:string)
        tok = advance
        return tok.type == :number ? AST::NumberLit.new(value: tok.value) : AST::StringLit.new(value: tok.value)
      end

      if match(:true)
        return AST::BoolLit.new(value: true)
      end

      if match(:false)
        return AST::BoolLit.new(value: false)
      end

      if match(:nil)
        return AST::NilLit.new
      end

      if check(:identifier)
        return AST::Identifier.new(name: advance.value)
      end

      if match(:lparen)
        expr = parse_expression
        consume(:rparen, "Expected ')'")
        return expr
      end

      return parse_function if check(:fn)
      return parse_if if check(:if)
      return parse_while if check(:while)
      return parse_block if check(:do)

      raise Crux::SyntaxError, "Unexpected token '#{peek.value || peek.type}' at line #{peek.line}"
    end

    def parse_function
      consume(:fn, "Expected 'fn'")
      consume(:lparen, "Expected '(' after 'fn'")

      params = []
      unless check(:rparen)
        params << consume(:identifier, "Expected parameter name").value
        while match(:comma)
          params << consume(:identifier, "Expected parameter name").value
        end
      end

      consume(:rparen, "Expected ')' after parameters")
      consume(:arrow, "Expected '->' after parameters")
      skip_newlines
      body = parse_expression
      AST::Function.new(params: params, body: body)
    end

    def parse_if
      consume(:if, "Expected 'if'")
      condition = parse_expression
      consume(:then, "Expected 'then' after if condition")
      skip_newlines

      then_branch = parse_expression
      skip_newlines

      else_branch = nil
      if match(:else)
        skip_newlines
        else_branch = parse_expression
        skip_newlines
      end

      consume(:end, "Expected 'end' after if expression")
      AST::If.new(condition: condition, then_branch: then_branch, else_branch: else_branch)
    end

    def parse_while
      consume(:while, "Expected 'while'")
      condition = parse_expression
      consume(:do, "Expected 'do' after while condition")
      skip_newlines

      body = parse_block_body
      consume(:end, "Expected 'end' after while body")
      AST::While.new(condition: condition, body: body)
    end

    def parse_block
      consume(:do, "Expected 'do'")
      skip_newlines
      body = parse_block_body
      consume(:end, "Expected 'end' after block")
      body
    end

    def parse_block_body
      stmts = []
      until check(:end) || check(:else) || check(:eof)
        stmts << parse_statement
        skip_newlines
      end
      AST::Block.new(statements: stmts)
    end

    # -- Arguments ---------------------------------------------------------

    def parse_arguments
      args = [parse_expression]
      while match(:comma)
        args << parse_expression
      end
      args
    end

    # -- Token navigation --------------------------------------------------

    def peek
      @tokens[@pos]
    end

    def check(type)
      peek.type == type
    end

    def advance
      tok = @tokens[@pos]
      @pos += 1
      tok
    end

    def match(*types)
      types.each do |type|
        if check(type)
          return advance
        end
      end
      nil
    end

    def consume(type, message)
      return advance if check(type)

      raise Crux::SyntaxError, "#{message} (got '#{peek.value || peek.type}' at line #{peek.line})"
    end

    def skip_newlines
      advance while check(:newline)
    end
  end
end
