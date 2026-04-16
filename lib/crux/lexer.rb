# frozen_string_literal: true

module Crux
  # Transforms Crux source code into a flat array of Tokens.
  #
  # The lexer is single-pass and greedy. It handles:
  # - Numbers (integer and float)
  # - Strings (double-quoted, with escape sequences)
  # - Identifiers and keywords
  # - Operators and punctuation
  # - Comments (# to end of line)
  # - Newlines as statement separators
  class Lexer
    # source - A String of Crux source code.
    def initialize(source)
      @source = source
      @tokens = []
      @pos = 0
      @line = 1
      @column = 1
    end

    # Tokenize the entire source string.
    #
    # Returns an Array of Token.
    # Raises Crux::SyntaxError on invalid input.
    def tokenize
      while @pos < @source.length
        skip_whitespace_and_comments
        break if @pos >= @source.length

        tokenize_one
      end

      @tokens << Token.new(type: :eof, value: nil, line: @line, column: @column)
      @tokens
    end

    private

    def tokenize_one
      char = @source[@pos]

      case char
      when "\n"
        emit_newline
      when '"'
        read_string
      when /[0-9]/
        read_number
      when /[a-zA-Z_]/
        read_identifier
      when "|"
        read_pipe_or_error
      when "-"
        read_arrow_or_minus
      when "="
        read_equals
      when "!"
        read_bang
      when "<"
        read_less
      when ">"
        read_greater
      when "+"
        emit(:plus, "+")
      when "*"
        emit(:star, "*")
      when "/"
        emit(:slash, "/")
      when "%"
        emit(:percent, "%")
      when "("
        emit(:lparen, "(")
      when ")"
        emit(:rparen, ")")
      when "["
        emit(:lbracket, "[")
      when "]"
        emit(:rbracket, "]")
      when ","
        emit(:comma, ",")
      when ";"
        emit(:newline, ";")
      else
        raise Crux::SyntaxError, "Unexpected character '#{char}' at line #{@line}, column #{@column}"
      end
    end

    def skip_whitespace_and_comments
      while @pos < @source.length
        char = @source[@pos]
        if char == " " || char == "\t" || char == "\r"
          advance
        elsif char == "#"
          advance while @pos < @source.length && @source[@pos] != "\n"
        elsif char == "/" && @pos + 1 < @source.length && @source[@pos + 1] == "*"
          start_line = @line
          advance # skip /
          advance # skip *
          depth = 1
          while @pos < @source.length && depth > 0
            if @source[@pos] == "/" && @pos + 1 < @source.length && @source[@pos + 1] == "*"
              advance
              advance
              depth += 1
            elsif @source[@pos] == "*" && @pos + 1 < @source.length && @source[@pos + 1] == "/"
              advance
              advance
              depth -= 1
            else
              advance
            end
          end
          raise Crux::SyntaxError, "Unterminated block comment at line #{start_line}" if depth > 0
        else
          break
        end
      end
    end

    def read_string
      start_line = @line
      start_col = @column
      advance # skip opening quote
      value = +""

      while @pos < @source.length && @source[@pos] != '"'
        if @source[@pos] == "\\"
          advance
          value << case @source[@pos]
                   when "n" then "\n"
                   when "t" then "\t"
                   when "\\" then "\\"
                   when '"' then '"'
                   else
                     raise Crux::SyntaxError, "Invalid escape '\\#{@source[@pos]}' at line #{@line}"
                   end
        else
          value << @source[@pos]
        end
        advance
      end

      raise Crux::SyntaxError, "Unterminated string at line #{start_line}" if @pos >= @source.length

      advance # skip closing quote
      @tokens << Token.new(type: :string, value: value, line: start_line, column: start_col)
    end

    def read_number
      start_col = @column
      number = +""
      number << advance while @pos < @source.length && @source[@pos] =~ /[0-9]/

      if @pos < @source.length && @source[@pos] == "." && @pos + 1 < @source.length && @source[@pos + 1] =~ /[0-9]/
        number << advance # the dot
        number << advance while @pos < @source.length && @source[@pos] =~ /[0-9]/
        @tokens << Token.new(type: :number, value: number.to_f, line: @line, column: start_col)
      else
        @tokens << Token.new(type: :number, value: number.to_i, line: @line, column: start_col)
      end
    end

    def read_identifier
      start_col = @column
      word = +""
      word << advance while @pos < @source.length && @source[@pos] =~ /[a-zA-Z0-9_]/

      type = KEYWORDS.fetch(word, :identifier)
      value = case type
              when :true then true
              when :false then false
              when :nil then nil
              else word
              end

      @tokens << Token.new(type: type, value: value, line: @line, column: start_col)
    end

    def read_pipe_or_error
      start_col = @column
      advance
      if @pos < @source.length && @source[@pos] == ">"
        advance
        @tokens << Token.new(type: :pipe, value: "|>", line: @line, column: start_col)
      else
        raise Crux::SyntaxError, "Expected '>' after '|' at line #{@line}, column #{@column}"
      end
    end

    def read_arrow_or_minus
      start_col = @column
      advance
      if @pos < @source.length && @source[@pos] == ">"
        advance
        @tokens << Token.new(type: :arrow, value: "->", line: @line, column: start_col)
      else
        @tokens << Token.new(type: :minus, value: "-", line: @line, column: start_col)
      end
    end

    def read_equals
      start_col = @column
      advance
      if @pos < @source.length && @source[@pos] == "="
        advance
        @tokens << Token.new(type: :equal_equal, value: "==", line: @line, column: start_col)
      else
        @tokens << Token.new(type: :equal, value: "=", line: @line, column: start_col)
      end
    end

    def read_bang
      start_col = @column
      advance
      if @pos < @source.length && @source[@pos] == "="
        advance
        @tokens << Token.new(type: :bang_equal, value: "!=", line: @line, column: start_col)
      else
        raise Crux::SyntaxError, "Expected '=' after '!' at line #{@line}, column #{@column}"
      end
    end

    def read_less
      start_col = @column
      advance
      if @pos < @source.length && @source[@pos] == "="
        advance
        @tokens << Token.new(type: :less_equal, value: "<=", line: @line, column: start_col)
      else
        @tokens << Token.new(type: :less, value: "<", line: @line, column: start_col)
      end
    end

    def read_greater
      start_col = @column
      advance
      if @pos < @source.length && @source[@pos] == "="
        advance
        @tokens << Token.new(type: :greater_equal, value: ">=", line: @line, column: start_col)
      else
        @tokens << Token.new(type: :greater, value: ">", line: @line, column: start_col)
      end
    end

    def emit(type, value)
      @tokens << Token.new(type: type, value: value, line: @line, column: @column)
      advance
    end

    def emit_newline
      # Collapse consecutive newlines into one, and skip leading newlines
      unless @tokens.empty? || @tokens.last.type == :newline
        @tokens << Token.new(type: :newline, value: "\n", line: @line, column: @column)
      end
      advance
    end

    def advance
      char = @source[@pos]
      @pos += 1
      if char == "\n"
        @line += 1
        @column = 1
      else
        @column += 1
      end
      char
    end
  end
end
