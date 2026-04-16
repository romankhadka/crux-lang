# frozen_string_literal: true

module Crux
  # A closure: a function body paired with the environment it was defined in.
  #
  # params - An Array of String parameter names.
  # body   - An AST node.
  # env    - The Environment captured at definition time.
  Closure = Data.define(:params, :rest_param, :body, :env)

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

      in AST::Interpolation[parts:]
        parts.map { |p| stringify(evaluate(p, env)) }.join

      in AST::ArrayLit[elements:]
        elements.map { |e| evaluate(e, env) }

      in AST::HashLit[pairs:]
        pairs.each_with_object({}) do |(k, v), hash|
          hash[evaluate(k, env)] = evaluate(v, env)
        end

      in AST::Identifier[name:]
        env.fetch(name)

      in AST::LetBinding[name:, value:]
        env.define(name, evaluate(value, env))

      in AST::Assignment[name:, value:]
        env.assign(name, evaluate(value, env))

      in AST::IndexAccess[object:, index:]
        evaluate_index_access(object, index, env)

      in AST::IndexAssign[object:, index:, value:]
        evaluate_index_assign(object, index, value, env)

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

      in AST::ForIn[name:, iterable:, body:]
        collection = evaluate(iterable, env)
        raise Crux::RuntimeError, "for-in requires an array, got #{type_name(collection)}" unless collection.is_a?(Array)
        result = nil
        collection.each do |item|
          loop_env = Environment.new(parent: env)
          loop_env.define(name, item)
          result = evaluate(body, loop_env)
        end
        result

      in AST::Block[statements:]
        evaluate_block(statements, env)

      in AST::Function[params:, rest_param:, body:]
        Closure.new(params: params, rest_param: rest_param, body: body, env: env)

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
      when Hash then "{#{value.map { |k, v| "#{stringify(k)}: #{stringify(v)}" }.join(", ")}}"
      when Array then "[#{value.map { |v| stringify(v) }.join(", ")}]"
      when Closure
        all_params = value.params.dup
        all_params << "...#{value.rest_param}" if value.rest_param
        "<fn(#{all_params.join(", ")})>"
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

    def evaluate_index_access(object_node, index_node, env)
      obj = evaluate(object_node, env)
      idx = evaluate(index_node, env)

      case obj
      when Array
        raise Crux::RuntimeError, "Array index must be a number" unless idx.is_a?(Integer)
        raise Crux::RuntimeError, "Array index #{idx} out of bounds (size: #{obj.length})" if idx >= obj.length || idx < -obj.length
        obj[idx]
      when Hash
        obj[idx]
      when String
        raise Crux::RuntimeError, "String index must be a number" unless idx.is_a?(Integer)
        raise Crux::RuntimeError, "String index #{idx} out of bounds (size: #{obj.length})" if idx >= obj.length || idx < -obj.length
        obj[idx]
      else
        raise Crux::RuntimeError, "Cannot index into #{type_name(obj)}"
      end
    end

    def evaluate_index_assign(object_node, index_node, value_node, env)
      obj = evaluate(object_node, env)
      idx = evaluate(index_node, env)
      val = evaluate(value_node, env)

      case obj
      when Array
        raise Crux::RuntimeError, "Array index must be a number" unless idx.is_a?(Integer)
        raise Crux::RuntimeError, "Array index #{idx} out of bounds (size: #{obj.length})" if idx >= obj.length || idx < -obj.length
        obj[idx] = val
      when Hash
        obj[idx] = val
      else
        raise Crux::RuntimeError, "Cannot assign to index of #{type_name(obj)}"
      end
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
      in Closure[params:, rest_param:, body:, env:]
        if rest_param
          if args.length < params.length
            raise Crux::RuntimeError, "Expected at least #{params.length} arguments, got #{args.length}"
          end
        elsif args.length != params.length
          raise Crux::RuntimeError, "Expected #{params.length} arguments, got #{args.length}"
        end

        call_env = Environment.new(parent: env)
        params.each_with_index { |name, i| call_env.define(name, args[i]) }
        call_env.define(rest_param, args[params.length..]) if rest_param
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
      when Hash then "hash"
      when Array then "array"
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
          case val
          when String, Array then val.length
          when Hash then val.size
          else raise Crux::RuntimeError, "len() expects a string, array, or hash, got #{type_name(val)}"
          end
        },
      ))

      @globals.define("keys", Builtin.new(
        name: "keys",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "keys() expects a hash" unless val.is_a?(Hash)
          val.keys
        },
      ))

      @globals.define("values", Builtin.new(
        name: "values",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "values() expects a hash" unless val.is_a?(Hash)
          val.values
        },
      ))

      @globals.define("has_key", Builtin.new(
        name: "has_key",
        arity: 2,
        body: ->(hash, key) {
          raise Crux::RuntimeError, "has_key() expects a hash" unless hash.is_a?(Hash)
          hash.key?(key)
        },
      ))

      @globals.define("merge", Builtin.new(
        name: "merge",
        arity: 2,
        body: ->(a, b) {
          raise Crux::RuntimeError, "merge() expects two hashes" unless a.is_a?(Hash) && b.is_a?(Hash)
          a.merge(b)
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
      register_string_builtins
      register_array_builtins
    end

    def register_string_builtins
      @globals.define("upper", Builtin.new(
        name: "upper",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "upper() expects a string" unless val.is_a?(String)
          val.upcase
        },
      ))

      @globals.define("lower", Builtin.new(
        name: "lower",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "lower() expects a string" unless val.is_a?(String)
          val.downcase
        },
      ))

      @globals.define("trim", Builtin.new(
        name: "trim",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "trim() expects a string" unless val.is_a?(String)
          val.strip
        },
      ))

      @globals.define("split", Builtin.new(
        name: "split",
        arity: 2,
        body: ->(val, delim) {
          raise Crux::RuntimeError, "split() expects strings" unless val.is_a?(String) && delim.is_a?(String)
          val.split(delim)
        },
      ))

      @globals.define("replace", Builtin.new(
        name: "replace",
        arity: 3,
        body: ->(val, pattern, replacement) {
          raise Crux::RuntimeError, "replace() expects strings" unless [val, pattern, replacement].all? { |v| v.is_a?(String) }
          val.gsub(pattern, replacement)
        },
      ))

      @globals.define("contains", Builtin.new(
        name: "contains",
        arity: 2,
        body: ->(val, substr) {
          raise Crux::RuntimeError, "contains() expects strings" unless val.is_a?(String) && substr.is_a?(String)
          val.include?(substr)
        },
      ))

      @globals.define("chars", Builtin.new(
        name: "chars",
        arity: 1,
        body: ->(val) {
          raise Crux::RuntimeError, "chars() expects a string" unless val.is_a?(String)
          val.chars
        },
      ))

      @globals.define("slice", Builtin.new(
        name: "slice",
        arity: 3,
        body: ->(val, start, len) {
          raise Crux::RuntimeError, "slice() expects a string and two numbers" unless val.is_a?(String) && start.is_a?(Integer) && len.is_a?(Integer)
          val[start, len] || ""
        },
      ))
    end

    def register_array_builtins
      @globals.define("push", Builtin.new(
        name: "push",
        arity: 2,
        body: ->(arr, val) {
          raise Crux::RuntimeError, "push() expects an array" unless arr.is_a?(Array)
          arr.push(val)
          arr
        },
      ))

      @globals.define("pop", Builtin.new(
        name: "pop",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "pop() expects an array" unless arr.is_a?(Array)
          raise Crux::RuntimeError, "pop() on empty array" if arr.empty?
          arr.pop
        },
      ))

      @globals.define("first", Builtin.new(
        name: "first",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "first() expects an array" unless arr.is_a?(Array)
          arr.first
        },
      ))

      @globals.define("last", Builtin.new(
        name: "last",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "last() expects an array" unless arr.is_a?(Array)
          arr.last
        },
      ))

      @globals.define("reverse", Builtin.new(
        name: "reverse",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "reverse() expects an array" unless arr.is_a?(Array)
          arr.reverse
        },
      ))

      @globals.define("sort", Builtin.new(
        name: "sort",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "sort() expects an array" unless arr.is_a?(Array)
          arr.sort
        },
      ))

      @globals.define("join", Builtin.new(
        name: "join",
        arity: 2,
        body: ->(arr, sep) {
          raise Crux::RuntimeError, "join() expects an array and a string" unless arr.is_a?(Array) && sep.is_a?(String)
          arr.map { |v| stringify(v) }.join(sep)
        },
      ))

      @globals.define("map", Builtin.new(
        name: "map",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "map() expects an array" unless arr.is_a?(Array)
          arr.map { |item| call_function(func, [item]) }
        },
      ))

      @globals.define("filter", Builtin.new(
        name: "filter",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "filter() expects an array" unless arr.is_a?(Array)
          arr.select { |item| truthy?(call_function(func, [item])) }
        },
      ))

      @globals.define("reduce", Builtin.new(
        name: "reduce",
        arity: 3,
        body: ->(arr, init, func) {
          raise Crux::RuntimeError, "reduce() expects an array" unless arr.is_a?(Array)
          arr.reduce(init) { |acc, item| call_function(func, [acc, item]) }
        },
      ))

      @globals.define("each", Builtin.new(
        name: "each",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "each() expects an array" unless arr.is_a?(Array)
          arr.each { |item| call_function(func, [item]) }
          nil
        },
      ))

      @globals.define("range", Builtin.new(
        name: "range",
        arity: 2,
        body: ->(start, stop) {
          raise Crux::RuntimeError, "range() expects numbers" unless start.is_a?(Integer) && stop.is_a?(Integer)
          (start...stop).to_a
        },
      ))

      @globals.define("concat", Builtin.new(
        name: "concat",
        arity: 2,
        body: ->(a, b) {
          raise Crux::RuntimeError, "concat() expects two arrays" unless a.is_a?(Array) && b.is_a?(Array)
          a + b
        },
      ))

      @globals.define("empty", Builtin.new(
        name: "empty",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "empty() expects an array" unless arr.is_a?(Array)
          arr.empty?
        },
      ))
    end
  end
end
