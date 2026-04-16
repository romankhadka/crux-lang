# frozen_string_literal: true

module Crux
  # A single lexical token produced by the Lexer.
  #
  # type   - A Symbol identifying the token kind (e.g., :number, :plus, :let).
  # value  - The raw String or numeric value of the token.
  # line   - An Integer line number (1-based).
  # column - An Integer column number (1-based).
  Token = Data.define(:type, :value, :line, :column)

  # All keyword tokens recognized by the language.
  KEYWORDS = %i[
    let fn if then else end do while for in
    try catch throw
    and or not true false nil
  ].to_h { |k| [k.to_s, k] }.freeze
end
