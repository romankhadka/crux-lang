# frozen_string_literal: true

module Crux
  # Recursive-descent parser that transforms a token stream into an AST.
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
      elsif check(:const)
        parse_const
      else
        expr = parse_expression

        # Postfix if/unless (Group K)
        if match(:if)
          cond = parse_expression
          return AST::If.new(condition: cond, then_branch: expr, else_branch: nil)
        elsif match(:unless)
          cond = parse_expression
          return AST::If.new(condition: AST::UnaryOp.new(operator: :not, operand: cond), then_branch: expr, else_branch: nil)
        end

        expr
      end
    end

    def parse_let
      consume(:let, "Expected 'let'")

      # Array destructuring: let [a, b, ...rest] = expr
      if check(:lbracket)
        return parse_let_destructure
      end

      name = consume(:identifier, "Expected variable name after 'let'").value
      consume(:equal, "Expected '=' after variable name")
      value = parse_expression
      AST::LetBinding.new(name: name, value: value)
    end

    def parse_let_destructure
      consume(:lbracket, "Expected '['")
      names = []
      rest_name = nil
      unless check(:rbracket)
        loop do
          if check(:dotdotdot)
            advance
            rest_name = consume(:identifier, "Expected name after '...'").value
            break
          end
          names << consume(:identifier, "Expected variable name").value
          break unless match(:comma)
        end
      end
      consume(:rbracket, "Expected ']' after destructuring pattern")
      consume(:equal, "Expected '=' after destructuring pattern")
      value = parse_expression
      AST::DestructureArray.new(names: names, rest_name: rest_name, value: value)
    end

    def parse_const
      consume(:const, "Expected 'const'")
      name = consume(:identifier, "Expected variable name after 'const'").value
      consume(:equal, "Expected '=' after variable name")
      value = parse_expression
      AST::ConstBinding.new(name: name, value: value)
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
      expr = parse_nil_coalesce

      # Compound assignment operators
      compound_ops = {
        plus_equal: :plus,
        minus_equal: :minus,
        star_equal: :star,
        slash_equal: :slash,
        percent_equal: :percent,
      }

      compound_ops.each do |tok_type, bin_op|
        if match(tok_type)
          value = parse_expression
          if expr.is_a?(AST::Identifier)
            return AST::Assignment.new(
              name: expr.name,
              value: AST::BinaryOp.new(operator: bin_op, left: expr, right: value),
            )
          elsif expr.is_a?(AST::IndexAccess)
            return AST::IndexAssign.new(
              object: expr.object,
              index: expr.index,
              value: AST::BinaryOp.new(
                operator: bin_op,
                left: expr,
                right: value,
              ),
            )
          else
            raise Crux::SyntaxError, "Invalid compound assignment target at line #{peek.line}"
          end
        end
      end

      if match(:equal)
        value = parse_expression
        if expr.is_a?(AST::Identifier)
          return AST::Assignment.new(name: expr.name, value: value)
        elsif expr.is_a?(AST::IndexAccess)
          return AST::IndexAssign.new(object: expr.object, index: expr.index, value: value)
        else
          raise Crux::SyntaxError, "Invalid assignment target at line #{peek.line}"
        end
      end

      expr
    end

    def parse_nil_coalesce
      left = parse_logic_or
      while match(:question_question)
        right = parse_logic_or
        left = AST::BinaryOp.new(operator: :question_question, left: left, right: right)
      end
      left
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
      left = parse_composition
      while (op = match(:less, :greater, :less_equal, :greater_equal, :spaceship))
        right = parse_composition
        left = AST::BinaryOp.new(operator: op.type, left: left, right: right)
      end
      left
    end

    def parse_composition
      left = parse_addition
      while (op = match(:compose_right, :compose_left))
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
      left = parse_exponent
      while (op = match(:star, :slash, :percent))
        right = parse_exponent
        left = AST::BinaryOp.new(operator: op.type, left: left, right: right)
      end
      left
    end

    def parse_exponent
      base = parse_unary
      if match(:star_star)
        right = parse_exponent # right-associative
        return AST::BinaryOp.new(operator: :star_star, left: base, right: right)
      end
      base
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

      loop do
        if check(:lparen)
          advance
          args = check(:rparen) ? [] : parse_arguments
          consume(:rparen, "Expected ')' after arguments")
          expr = AST::Call.new(callee: expr, arguments: args)
        elsif check(:lbracket)
          advance
          index = parse_expression
          consume(:rbracket, "Expected ']' after index")
          expr = AST::IndexAccess.new(object: expr, index: index)
        elsif check(:dot)
          advance
          method_name = consume(:identifier, "Expected method name after '.'").value
          args = [expr]
          if match(:lparen)
            unless check(:rparen)
              args += parse_arguments
            end
            consume(:rparen, "Expected ')' after method arguments")
          end
          expr = AST::Call.new(callee: AST::Identifier.new(name: method_name), arguments: args)
        else
          break
        end
      end

      expr
    end

    # -- Primary -----------------------------------------------------------

    def parse_primary
      if check(:interp_start)
        return parse_interpolation
      end

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

      if check(:lbracket)
        return parse_array
      end

      if check(:lbrace)
        return parse_hash
      end

      return parse_function if check(:fn)
      return parse_if if check(:if)
      return parse_unless if check(:unless)
      return parse_while if check(:while)
      return parse_until if check(:until)
      return parse_loop if check(:loop)
      return parse_for_in if check(:for)
      return parse_try_catch if check(:try)
      return parse_throw if check(:throw)
      return parse_match if check(:match)
      return parse_block if check(:do)
      return parse_break if check(:break)
      return parse_continue if check(:continue)
      return parse_return if check(:return)

      raise Crux::SyntaxError, "Unexpected token '#{peek.value || peek.type}' at line #{peek.line}"
    end

    def parse_interpolation
      consume(:interp_start, "Expected interpolation start")
      parts = []
      until check(:interp_end) || check(:eof)
        if check(:string)
          parts << AST::StringLit.new(value: advance.value)
        else
          parts << parse_expression
        end
      end
      consume(:interp_end, "Expected interpolation end")
      AST::Interpolation.new(parts: parts)
    end

    def parse_hash
      consume(:lbrace, "Expected '{'")
      skip_newlines
      pairs = []
      unless check(:rbrace)
        loop do
          skip_newlines
          break if check(:rbrace) # trailing comma
          key = parse_expression
          consume(:colon, "Expected ':' after hash key")
          value = parse_expression
          pairs << [key, value]
          skip_newlines
          break unless match(:comma)
          skip_newlines
        end
      end
      skip_newlines
      consume(:rbrace, "Expected '}' after hash entries")
      AST::HashLit.new(pairs: pairs)
    end

    def parse_array
      consume(:lbracket, "Expected '['")
      skip_newlines
      elements = []
      unless check(:rbracket)
        elements << parse_expression
        while match(:comma)
          skip_newlines
          break if check(:rbracket) # trailing comma
          elements << parse_expression
        end
      end
      skip_newlines
      consume(:rbracket, "Expected ']' after array elements")
      AST::ArrayLit.new(elements: elements)
    end

    def parse_function
      consume(:fn, "Expected 'fn'")
      consume(:lparen, "Expected '(' after 'fn'")

      params = []
      defaults = {}
      rest_param = nil
      unless check(:rparen)
        if check(:dotdotdot)
          advance
          rest_param = consume(:identifier, "Expected parameter name after '...'").value
        else
          name = consume(:identifier, "Expected parameter name").value
          params << name
          if match(:equal)
            defaults[name] = parse_expression
          end
          while match(:comma)
            break if check(:rparen) # trailing comma
            if check(:dotdotdot)
              advance
              rest_param = consume(:identifier, "Expected parameter name after '...'").value
              break
            end
            name = consume(:identifier, "Expected parameter name").value
            params << name
            if match(:equal)
              defaults[name] = parse_expression
            end
          end
        end
      end

      consume(:rparen, "Expected ')' after parameters")
      consume(:arrow, "Expected '->' after parameters")
      skip_newlines
      body = parse_expression
      AST::Function.new(params: params, rest_param: rest_param, defaults: defaults, body: body)
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

    def parse_unless
      consume(:unless, "Expected 'unless'")
      condition = parse_expression
      consume(:then, "Expected 'then' after unless condition")
      skip_newlines

      then_branch = parse_expression
      skip_newlines

      else_branch = nil
      if match(:else)
        skip_newlines
        else_branch = parse_expression
        skip_newlines
      end

      consume(:end, "Expected 'end' after unless expression")
      # Desugar: unless cond => if not cond
      AST::If.new(
        condition: AST::UnaryOp.new(operator: :not, operand: condition),
        then_branch: then_branch,
        else_branch: else_branch,
      )
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

    def parse_until
      consume(:until, "Expected 'until'")
      condition = parse_expression
      consume(:do, "Expected 'do' after until condition")
      skip_newlines

      body = parse_block_body
      consume(:end, "Expected 'end' after until body")
      # Desugar: until cond => while not cond
      AST::While.new(
        condition: AST::UnaryOp.new(operator: :not, operand: condition),
        body: body,
      )
    end

    def parse_loop
      consume(:loop, "Expected 'loop'")
      consume(:do, "Expected 'do' after 'loop'")
      skip_newlines

      body = parse_block_body
      consume(:end, "Expected 'end' after loop body")
      # Desugar: loop => while true
      AST::While.new(condition: AST::BoolLit.new(value: true), body: body)
    end

    def parse_break
      consume(:break, "Expected 'break'")
      value = nil
      # break can have an optional value if next token is not a terminator
      unless check(:newline) || check(:eof) || check(:end) || check(:else)
        value = parse_expression
      end
      AST::Break.new(value: value)
    end

    def parse_continue
      consume(:continue, "Expected 'continue'")
      AST::Continue.new
    end

    def parse_return
      consume(:return, "Expected 'return'")
      value = nil
      unless check(:newline) || check(:eof) || check(:end) || check(:else)
        value = parse_expression
      end
      AST::Return.new(value: value)
    end

    def parse_try_catch
      consume(:try, "Expected 'try'")
      skip_newlines
      body = parse_try_body
      consume(:catch, "Expected 'catch' after try body")
      error_name = consume(:identifier, "Expected error variable name after 'catch'").value
      consume(:arrow, "Expected '->' after catch variable")
      skip_newlines
      handler = parse_catch_body
      finally_body = nil
      if match(:finally)
        consume(:arrow, "Expected '->' after 'finally'")
        skip_newlines
        finally_body = parse_block_body
      end
      consume(:end, "Expected 'end' after try-catch")
      AST::TryCatch.new(body: body, error_name: error_name, handler: handler, finally_body: finally_body)
    end

    def parse_try_body
      stmts = []
      until check(:catch) || check(:eof)
        stmts << parse_statement
        skip_newlines
      end
      stmts.length == 1 ? stmts.first : AST::Block.new(statements: stmts)
    end

    def parse_catch_body
      stmts = []
      until check(:end) || check(:finally) || check(:eof)
        stmts << parse_statement
        skip_newlines
      end
      AST::Block.new(statements: stmts)
    end

    def parse_throw
      consume(:throw, "Expected 'throw'")
      message = parse_expression
      AST::Throw.new(message: message)
    end

    def parse_for_in
      consume(:for, "Expected 'for'")

      # Check for destructuring: for [k, v] in ...
      if check(:lbracket)
        advance
        names = []
        names << consume(:identifier, "Expected variable name").value
        while match(:comma)
          names << consume(:identifier, "Expected variable name").value
        end
        consume(:rbracket, "Expected ']' after destructuring pattern")
        consume(:in, "Expected 'in' after variable name")
        iterable = parse_expression
        consume(:do, "Expected 'do' after for-in iterable")
        skip_newlines
        body = parse_block_body
        consume(:end, "Expected 'end' after for-in body")
        return AST::ForIn.new(name: names, iterable: iterable, body: body)
      end

      name = consume(:identifier, "Expected variable name after 'for'").value
      consume(:in, "Expected 'in' after variable name")
      iterable = parse_expression
      consume(:do, "Expected 'do' after for-in iterable")
      skip_newlines
      body = parse_block_body
      consume(:end, "Expected 'end' after for-in body")
      AST::ForIn.new(name: name, iterable: iterable, body: body)
    end

    def parse_match
      consume(:match, "Expected 'match'")
      subject = parse_expression
      skip_newlines

      arms = []
      while match(:when)
        # Pattern: literal, identifier, or _ wildcard
        pattern = parse_expression
        guard = nil
        if match(:if)
          guard = parse_expression
        end
        consume(:arrow, "Expected '->' after match pattern")
        skip_newlines
        body = parse_match_arm_body
        skip_newlines
        arms << AST::MatchArm.new(pattern: pattern, guard: guard, body: body)
      end

      consume(:end, "Expected 'end' after match expression")
      AST::Match.new(subject: subject, arms: arms)
    end

    def parse_match_arm_body
      stmts = []
      until check(:when) || check(:end) || check(:eof)
        stmts << parse_statement
        skip_newlines
      end
      stmts.length == 1 ? stmts.first : AST::Block.new(statements: stmts)
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
        break if check(:rparen) # trailing comma
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
