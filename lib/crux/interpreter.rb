# frozen_string_literal: true

module Crux
  # A closure: a function body paired with the environment it was defined in.
  #
  # params - An Array of String parameter names.
  # body   - An AST node.
  # env    - The Environment captured at definition time.
  Closure = Data.define(:params, :body, :env)

  # A built-in function implemented in Ruby.
  #
  # name  - A String name for error messages.
  # arity - An Integer or Range of accepted argument counts.
  # body  - A Proc that implements the function.
  Builtin = Data.define(:name, :arity, :body)

  # Tree-walk interpreter that evaluates an AST.
  #
  # The interpreter maintains a global Environment and evaluates
  # nodes by pattern matching on their type. Functions create
  # closures that capture their defining scope, enabling
  # first-class functions and closures.
  class Interpreter
    attr_reader :globals

    def initialize(output: $stdout)
      @output = output
      @globals = Environment.new
      register_builtins
    end

    # Evaluate an AST node in the current environment.
    #
    # node - An AST node (typically AST::Program).
    # env  - An Environment (default: globals).
    #
    # Returns the result of evaluation.
    def evaluate(node, env = @globals)
      case node
      in AST::Program[statements:]
        evaluate_program(statements, env)

      in AST::NumberLit => lit
        lit.value

      in AST::StringLit => lit
        lit.value

      in AST::BoolLit => lit
        lit.value

      in AST::NilLit
        nil

      in AST::Identifier[name:]
        env.fetch(name)

      in AST::LetBinding[name:, value:]
        env.define(name, evaluate(value, env))

      in AST::Assignment[name:, value:]
        env.assign(name, evaluate(value, env))

      in AST::UnaryOp[operator:, operand:]
        evaluate_unary(operator, operand, env)

      in AST::BinaryOp[operator:, left:, right:]
        evaluate_binary(operator, left, right, env)

      in AST::If[condition:, then_branch:, else_branch:]
        if truthy?(evaluate(condition, env))
          evaluate(then_branch, env)
        elsif else_branch
          evaluate(else_branch, env)
        end

      in AST::While[condition:, body:]
        result = nil
        result = evaluate(body, env) while truthy?(evaluate(condition, env))
        result

      in AST::Block[statements:]
        evaluate_block(statements, env)

      in AST::Function[params:, body:]
        Closure.new(params: params, body: body, env: env)

      in AST::Call[callee:, arguments:]
        func = evaluate(callee, env)
        args = arguments.map { |a| evaluate(a, env) }
        call_function(func, args)

      in AST::Pipe[value:, function:, arguments:]
        piped = evaluate(value, env)
        func = evaluate(function, env)
        args = [piped] + arguments.map { |a| evaluate(a, env) }
        call_function(func, args)

      else
        raise Crux::RuntimeError, "Unknown AST node: #{node.class}"
      end
    end

    # Convert a Crux value to its string representation.
    #
    # value - Any Crux value.
    #
    # Returns a String.
    def stringify(value)
      case value
      when nil then "nil"
      when true then "true"
      when false then "false"
      when Float
        value == value.to_i ? value.to_i.to_s : value.to_s
      when Closure then "<fn(#{value.params.join(", ")})>"
      when Builtin then "<builtin:#{value.name}>"
      else value.to_s
      end
    end

    private

    def evaluate_program(statements, env)
      result = nil
      statements.each { |stmt| result = evaluate(stmt, env) }
      result
    end

    def evaluate_block(statements, env)
      block_env = Environment.new(parent: env)
      result = nil
      statements.each { |stmt| result = evaluate(stmt, block_env) }
      result
    end

    def evaluate_unary(operator, operand, env)
      val = evaluate(operand, env)
      case operator
      when :minus
        check_number(val, "-")
        -val
      when :not
        !truthy?(val)
      end
    end

    def evaluate_binary(operator, left_node, right_node, env)
      # Short-circuit for logical operators
      if operator == :and
        left = evaluate(left_node, env)
        return left unless truthy?(left)
        return evaluate(right_node, env)
      end

      if operator == :or
        left = evaluate(left_node, env)
        return left if truthy?(left)
        return evaluate(right_node, env)
      end

      left = evaluate(left_node, env)
      right = evaluate(right_node, env)

      case operator
      when :plus
        if left.is_a?(String) && right.is_a?(String)
          left + right
        elsif left.is_a?(Numeric) && right.is_a?(Numeric)
          left + right
        else
          raise Crux::RuntimeError, "Cannot add #{type_name(left)} and #{type_name(right)}"
        end
      when :minus
        check_numbers(left, right, "-")
        left - right
      when :star
        check_numbers(left, right, "*")
        left * right
      when :slash
        check_numbers(left, right, "/")
        raise Crux::RuntimeError, "Division by zero" if right.zero?
        left.is_a?(Integer) && right.is_a?(Integer) ? left / right : left.to_f / right
      when :percent
        check_numbers(left, right, "%")
        raise Crux::RuntimeError, "Modulo by zero" if right.zero?
        left % right
      when :equal_equal then left == right
      when :bang_equal then left != right
      when :less then check_comparable(left, right, "<"); left < right
      when :greater then check_comparable(left, right, ">"); left > right
      when :less_equal then check_comparable(left, right, "<="); left <= right
      when :greater_equal then check_comparable(left, right, ">="); left >= right
      end
    end

    def call_function(func, args)
      case func
      in Closure[params:, body:, env:]
        if args.length != params.length
          raise Crux::RuntimeError, "Expected #{params.length} arguments, got #{args.length}"
        end

        call_env = Environment.new(parent: env)
        params.each_with_index { |name, i| call_env.define(name, args[i]) }
        evaluate(body, call_env)

      in Builtin[name:, arity:, body:]
        valid_arity = arity.is_a?(Range) ? arity.cover?(args.length) : args.length == arity
        unless valid_arity
          raise Crux::RuntimeError, "#{name} expected #{arity} arguments, got #{args.length}"
        end
        body.call(*args)

      else
        raise Crux::RuntimeError, "Cannot call #{type_name(func)} — not a function"
      end
    end

    def truthy?(value)
      value != nil && value != false
    end

    def type_name(value)
      case value
      when Integer, Float then "number"
      when String then "string"
      when true, false then "boolean"
      when nil then "nil"
      when Closure then "function"
      when Builtin then "builtin"
      else value.class.name
      end
    end

    def check_number(val, op)
      raise Crux::RuntimeError, "Operand for '#{op}' must be a number, got #{type_name(val)}" unless val.is_a?(Numeric)
    end

    def check_numbers(left, right, op)
      return if left.is_a?(Numeric) && right.is_a?(Numeric)

      raise Crux::RuntimeError, "Operands for '#{op}' must be numbers, got #{type_name(left)} and #{type_name(right)}"
    end

    def check_comparable(left, right, op)
      return if (left.is_a?(Numeric) && right.is_a?(Numeric)) || (left.is_a?(String) && right.is_a?(String))

      raise Crux::RuntimeError, "Cannot compare #{type_name(left)} and #{type_name(right)} with '#{op}'"
    end

    # -- Built-in functions ------------------------------------------------

    def register_builtins
      @globals.define("print", Builtin.new(
        name: "print",
        arity: 1,
        body: ->(val) { @output.puts(stringify(val)); nil },
      ))

      @globals.define("println", Builtin.new(
        name: "println",
        arity: (0..),
        body: ->(*vals) { @output.puts(vals.map { |v| stringify(v) }.join(" ")); nil },
      ))

      @globals.define("str", Builtin.new(
        name: "str",
        arity: 1,
        body: ->(val) { stringify(val) },
      ))

      @globals.define("len", Builtin.new(
        name: "len",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "len() expects a string, got #{type_name(val)}" unless val.is_a?(String)
          val.length
        },
      ))

      @globals.define("type", Builtin.new(
        name: "type",
        arity: 1,
        body: ->(val) { type_name(val) },
      ))

      @globals.define("abs", Builtin.new(
        name: "abs",
        arity: 1,
        body: ->(val) {
          check_number(val, "abs")
          val.abs
        },
      ))

      @globals.define("max", Builtin.new(
        name: "max",
        arity: 2,
        body: ->(a, b) {
          check_numbers(a, b, "max")
          [a, b].max
        },
      ))

      @globals.define("min", Builtin.new(
        name: "min",
        arity: 2,
        body: ->(a, b) {
          check_numbers(a, b, "min")
          [a, b].min
        },
      ))

      @globals.define("to_int", Builtin.new(
        name: "to_int",
        arity: 1,
        body: ->(val) {
          case val
          when Integer then val
          when Float then val.to_i
          when String then Integer(val) rescue raise(Crux::RuntimeError, "Cannot convert '#{val}' to integer")
          else raise Crux::RuntimeError, "Cannot convert #{type_name(val)} to integer"
          end
        },
      ))

      @globals.define("floor", Builtin.new(
        name: "floor",
        arity: 1,
        body: ->(val) {
          check_number(val, "floor")
          val.floor
        },
      ))

      @globals.define("ceil", Builtin.new(
        name: "ceil",
        arity: 1,
        body: ->(val) {
          check_number(val, "ceil")
          val.ceil
        },
      ))

      @globals.define("round", Builtin.new(
        name: "round",
        arity: (1..2),
        body: ->(val, digits = 0) {
          check_number(val, "round")
          val.round(digits)
        },
      ))

      @globals.define("sqrt", Builtin.new(
        name: "sqrt",
        arity: 1,
        body: ->(val) {
          check_number(val, "sqrt")
          raise Crux::RuntimeError, "sqrt() domain error: negative number" if val.negative?
          Math.sqrt(val)
        },
      ))

      @globals.define("pow", Builtin.new(
        name: "pow",
        arity: 2,
        body: ->(base, exp) {
          check_numbers(base, exp, "pow")
          base ** exp
        },
      ))

      @globals.define("random", Builtin.new(
        name: "random",
        arity: 0,
        body: -> { rand },
      ))

      @globals.define("to_float", Builtin.new(
        name: "to_float",
        arity: 1,
        body: ->(val) {
          case val
          when Float then val
          when Integer then val.to_f
          when String then Float(val) rescue raise(Crux::RuntimeError, "Cannot convert '#{val}' to float")
          else raise Crux::RuntimeError, "Cannot convert #{type_name(val)} to float"
          end
        },
      ))
    end
  end
end
