# frozen_string_literal: true

require_relative "crux/token"
require_relative "crux/ast"
require_relative "crux/lexer"
require_relative "crux/parser"
require_relative "crux/environment"
require_relative "crux/interpreter"

module Crux
  VERSION = "0.1.0"

  # Run a Crux program from source code.
  #
  # source - A String of Crux source code.
  #
  # Returns the result of the last expression.
  def self.run(source)
    tokens = Lexer.new(source).tokenize
    ast = Parser.new(tokens).parse
    Interpreter.new.evaluate(ast)
  end

  # Start an interactive REPL session.
  #
  # input  - IO object to read from (default: $stdin).
  # output - IO object to write to (default: $stdout).
  #
  # Returns nothing.
  def self.repl(input: $stdin, output: $stdout)
    interpreter = Interpreter.new
    output.print "crux> "

    while (line = input.gets)
      line = line.chomp
      break if line == "exit" || line == "quit"
      next if line.empty?

      begin
        tokens = Lexer.new(line).tokenize
        ast = Parser.new(tokens).parse
        result = interpreter.evaluate(ast)
        output.puts "=> #{interpreter.stringify(result)}" unless result.nil?
      rescue Crux::SyntaxError, Crux::RuntimeError => e
        output.puts "Error: #{e.message}"
      end

      output.print "crux> "
    end

    output.puts
  end

  # Base error for all Crux errors.
  class Error < StandardError; end

  # Raised when the lexer or parser encounters invalid syntax.
  class SyntaxError < Error; end

  # Raised when the interpreter encounters an error at runtime.
  class RuntimeError < Error; end

  # Raised by the throw keyword in user code.
  class UserError < RuntimeError; end
end
