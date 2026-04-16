# frozen_string_literal: true

module Crux
  # A closure: a function body paired with the environment it was defined in.
  Closure = Data.define(:params, :rest_param, :defaults, :body, :env)

  # A built-in function implemented in Ruby.
  Builtin = Data.define(:name, :arity, :body)

  # Tree-walk interpreter that evaluates an AST.
  class Interpreter
    attr_reader :globals

    def initialize(output: $stdout)
      @output = output
      @globals = Environment.new
      @current_line = nil
      register_builtins
    end

    # Evaluate an AST node in the current environment.
    def evaluate(node, env = @globals)
      # Track line number for error messages
      @current_line = node_line(node)

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

      in AST::ConstBinding[name:, value:]
        env.define_const(name, evaluate(value, env))

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
        evaluate_while(condition, body, env)

      in AST::TryCatch[body:, error_name:, handler:, finally_body:]
        evaluate_try_catch(body, error_name, handler, finally_body, env)

      in AST::Throw[message:]
        msg = evaluate(message, env)
        raise Crux::UserError, stringify(msg)

      in AST::ForIn[name:, iterable:, body:]
        evaluate_for_in(name, iterable, body, env)

      in AST::Block[statements:]
        evaluate_block(statements, env)

      in AST::Function[params:, rest_param:, defaults:, body:]
        Closure.new(params: params, rest_param: rest_param, defaults: defaults, body: body, env: env)

      in AST::Call[callee:, arguments:]
        func = evaluate(callee, env)
        args = arguments.map { |a| evaluate(a, env) }
        call_function(func, args)

      in AST::Pipe[value:, function:, arguments:]
        piped = evaluate(value, env)
        func = evaluate(function, env)
        args = [piped] + arguments.map { |a| evaluate(a, env) }
        call_function(func, args)

      in AST::Break[value:]
        val = value ? evaluate(value, env) : nil
        raise BreakSignal.new(val)

      in AST::Continue
        raise ContinueSignal.new

      in AST::Return[value:]
        val = value ? evaluate(value, env) : nil
        raise ReturnSignal.new(val)

      in AST::Match[subject:, arms:]
        evaluate_match(subject, arms, env)

      in AST::DestructureArray[names:, rest_name:, value:]
        evaluate_destructure_array(names, rest_name, value, env)

      else
        raise Crux::RuntimeError, "Unknown AST node: #{node.class}"
      end
    rescue Crux::RuntimeError => e
      raise # re-raise as-is (already has context or is being handled)
    end

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

    def node_line(node)
      # AST nodes don't store line info, but we track it for runtime errors
      @current_line
    end

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

    def evaluate_while(condition, body, env)
      result = nil
      while truthy?(evaluate(condition, env))
        begin
          result = evaluate(body, env)
        rescue BreakSignal => e
          return e.value
        rescue ContinueSignal
          next
        end
      end
      result
    end

    def evaluate_for_in(name, iterable_node, body, env)
      collection = evaluate(iterable_node, env)
      raise Crux::RuntimeError, "for-in requires an array, got #{type_name(collection)}" unless collection.is_a?(Array)
      result = nil
      collection.each do |item|
        loop_env = Environment.new(parent: env)
        if name.is_a?(Array)
          # Destructuring: for [k, v] in pairs
          raise Crux::RuntimeError, "Destructuring requires array elements, got #{type_name(item)}" unless item.is_a?(Array)
          name.each_with_index do |n, i|
            loop_env.define(n, item[i])
          end
        else
          loop_env.define(name, item)
        end
        begin
          result = evaluate(body, loop_env)
        rescue BreakSignal => e
          return e.value
        rescue ContinueSignal
          next
        end
      end
      result
    end

    def evaluate_try_catch(body_node, error_name, handler, finally_body, env)
      result = begin
        evaluate(body_node, env)
      rescue Crux::RuntimeError, Crux::UserError => e
        handler_env = Environment.new(parent: env)
        handler_env.define(error_name, e.message)
        evaluate(handler, handler_env)
      end
      evaluate(finally_body, env) if finally_body
      result
    end

    def evaluate_match(subject_node, arms, env)
      subject = evaluate(subject_node, env)

      arms.each do |arm|
        pattern = arm.pattern

        # Wildcard: identifier "_"
        if pattern.is_a?(AST::Identifier) && pattern.name == "_"
          if arm.guard
            next unless truthy?(evaluate(arm.guard, env))
          end
          return evaluate(arm.body, env)
        end

        # Variable binding: identifier (non-wildcard)
        if pattern.is_a?(AST::Identifier)
          match_env = Environment.new(parent: env)
          match_env.define(pattern.name, subject)
          if arm.guard
            next unless truthy?(evaluate(arm.guard, match_env))
          end
          return evaluate(arm.body, match_env)
        end

        # Literal pattern: compare with ==
        pattern_val = evaluate(pattern, env)
        if subject == pattern_val
          if arm.guard
            next unless truthy?(evaluate(arm.guard, env))
          end
          return evaluate(arm.body, env)
        end
      end

      nil # no match
    end

    def evaluate_destructure_array(names, rest_name, value_node, env)
      val = evaluate(value_node, env)
      raise Crux::RuntimeError, "Destructuring requires an array, got #{type_name(val)}" unless val.is_a?(Array)

      names.each_with_index do |name, i|
        env.define(name, val[i])
      end

      if rest_name
        env.define(rest_name, val[names.length..] || [])
      end

      val
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

      # Nil coalescing (short-circuit)
      if operator == :question_question
        left = evaluate(left_node, env)
        return left unless left.nil?
        return evaluate(right_node, env)
      end

      # Function composition
      if operator == :compose_right
        f = evaluate(left_node, env)
        g = evaluate(right_node, env)
        return Closure.new(
          params: ["__x__"],
          rest_param: nil,
          defaults: {},
          body: nil,
          env: env,
        ).then do
          Builtin.new(
            name: "compose_right",
            arity: 1,
            body: ->(x) { call_function(g, [call_function(f, [x])]) },
          )
        end
      end

      if operator == :compose_left
        f = evaluate(left_node, env)
        g = evaluate(right_node, env)
        return Builtin.new(
          name: "compose_left",
          arity: 1,
          body: ->(x) { call_function(f, [call_function(g, [x])]) },
        )
      end

      left = evaluate(left_node, env)
      right = evaluate(right_node, env)

      case operator
      when :plus
        if left.is_a?(String) && right.is_a?(String)
          left + right
        elsif left.is_a?(Numeric) && right.is_a?(Numeric)
          left + right
        elsif left.is_a?(Array) && right.is_a?(Array)
          left + right
        else
          raise Crux::RuntimeError, "Cannot add #{type_name(left)} and #{type_name(right)}"
        end
      when :minus
        check_numbers(left, right, "-")
        left - right
      when :star
        if left.is_a?(String) && right.is_a?(Integer)
          left * right
        elsif left.is_a?(Array) && right.is_a?(Integer)
          left * right
        else
          check_numbers(left, right, "*")
          left * right
        end
      when :slash
        check_numbers(left, right, "/")
        raise Crux::RuntimeError, "Division by zero" if right.zero?
        left.is_a?(Integer) && right.is_a?(Integer) ? left / right : left.to_f / right
      when :percent
        check_numbers(left, right, "%")
        raise Crux::RuntimeError, "Modulo by zero" if right.zero?
        left % right
      when :star_star
        check_numbers(left, right, "**")
        left ** right
      when :spaceship
        check_comparable(left, right, "<=>")
        left <=> right
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
      in Closure[params:, rest_param:, defaults:, body:, env:]
        if rest_param
          if args.length < params.length
            raise Crux::RuntimeError, "Expected at least #{params.length} arguments, got #{args.length}"
          end
        else
          # With defaults, min arity is params without defaults
          required = params.reject { |p| defaults&.key?(p) }
          if args.length < required.length
            raise Crux::RuntimeError, "Expected #{params.length} arguments, got #{args.length}"
          elsif args.length > params.length
            raise Crux::RuntimeError, "Expected #{params.length} arguments, got #{args.length}"
          end
        end

        call_env = Environment.new(parent: env)
        params.each_with_index do |name, i|
          if i < args.length
            call_env.define(name, args[i])
          elsif defaults&.key?(name)
            call_env.define(name, evaluate(defaults[name], call_env))
          else
            call_env.define(name, nil)
          end
        end
        call_env.define(rest_param, args[params.length..]) if rest_param

        begin
          evaluate(body, call_env)
        rescue ReturnSignal => e
          e.value
        end

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
      # Global constants
      @globals.define("PI", Math::PI)
      @globals.define("E", Math::E)
      @globals.define("INFINITY", Float::INFINITY)
      @globals.define("NAN", Float::NAN)

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

      @globals.define("type", Builtin.new(
        name: "type",
        arity: 1,
        body: ->(val) { type_name(val) },
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
      register_hash_builtins
      register_math_builtins
      register_utility_builtins
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
          raise Crux::RuntimeError, "slice() expects two numbers for start and length" unless start.is_a?(Integer) && len.is_a?(Integer)
          case val
          when String then val[start, len] || ""
          when Array then val[start, len] || []
          else raise Crux::RuntimeError, "slice() expects a string or array, got #{type_name(val)}"
          end
        },
      ))

      @globals.define("starts_with", Builtin.new(
        name: "starts_with",
        arity: 2,
        body: ->(s, prefix) {
          raise Crux::RuntimeError, "starts_with() expects strings" unless s.is_a?(String) && prefix.is_a?(String)
          s.start_with?(prefix)
        },
      ))

      @globals.define("ends_with", Builtin.new(
        name: "ends_with",
        arity: 2,
        body: ->(s, suffix) {
          raise Crux::RuntimeError, "ends_with() expects strings" unless s.is_a?(String) && suffix.is_a?(String)
          s.end_with?(suffix)
        },
      ))

      @globals.define("pad_left", Builtin.new(
        name: "pad_left",
        arity: 3,
        body: ->(s, width, char) {
          raise Crux::RuntimeError, "pad_left() expects a string, number, and single-char string" unless s.is_a?(String) && width.is_a?(Integer) && char.is_a?(String) && char.length == 1
          s.rjust(width, char)
        },
      ))

      @globals.define("pad_right", Builtin.new(
        name: "pad_right",
        arity: 3,
        body: ->(s, width, char) {
          raise Crux::RuntimeError, "pad_right() expects a string, number, and single-char string" unless s.is_a?(String) && width.is_a?(Integer) && char.is_a?(String) && char.length == 1
          s.ljust(width, char)
        },
      ))

      @globals.define("index_of", Builtin.new(
        name: "index_of",
        arity: 2,
        body: ->(collection, target) {
          case collection
          when String
            raise Crux::RuntimeError, "index_of() target must be a string for string search" unless target.is_a?(String)
            collection.index(target) || -1
          when Array
            idx = collection.index(target)
            idx.nil? ? -1 : idx
          else
            raise Crux::RuntimeError, "index_of() expects a string or array, got #{type_name(collection)}"
          end
        },
      ))

      @globals.define("repeat", Builtin.new(
        name: "repeat",
        arity: 2,
        body: ->(val, n) {
          raise Crux::RuntimeError, "repeat() expects an integer count" unless n.is_a?(Integer)
          case val
          when String then val * n
          when Array then val * n
          else raise Crux::RuntimeError, "repeat() expects a string or array, got #{type_name(val)}"
          end
        },
      ))

      @globals.define("count", Builtin.new(
        name: "count",
        arity: 2,
        body: ->(collection, target_or_fn) {
          case collection
          when String
            raise Crux::RuntimeError, "count() target must be a string for string search" unless target_or_fn.is_a?(String)
            collection.scan(target_or_fn).length
          when Array
            if target_or_fn.is_a?(Closure) || target_or_fn.is_a?(Builtin)
              collection.count { |item| truthy?(call_function(target_or_fn, [item])) }
            else
              collection.count(target_or_fn)
            end
          else
            raise Crux::RuntimeError, "count() expects a string or array, got #{type_name(collection)}"
          end
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
        body: ->(val) {
          case val
          when Array then val.reverse
          when String then val.reverse
          else raise Crux::RuntimeError, "reverse() expects an array or string, got #{type_name(val)}"
          end
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
        arity: (2..3),
        body: ->(start, stop, step = 1) {
          raise Crux::RuntimeError, "range() expects numbers" unless start.is_a?(Integer) && stop.is_a?(Integer)
          raise Crux::RuntimeError, "range() step must be a non-zero integer" if step.is_a?(Integer) && step == 0
          if step > 0
            result = []
            i = start
            while i < stop
              result << i
              i += step
            end
            result
          else
            result = []
            i = start
            while i > stop
              result << i
              i += step
            end
            result
          end
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

      @globals.define("flatten", Builtin.new(
        name: "flatten",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "flatten() expects an array" unless arr.is_a?(Array)
          arr.flatten
        },
      ))

      @globals.define("zip", Builtin.new(
        name: "zip",
        arity: 2,
        body: ->(a, b) {
          raise Crux::RuntimeError, "zip() expects two arrays" unless a.is_a?(Array) && b.is_a?(Array)
          min_len = [a.length, b.length].min
          (0...min_len).map { |i| [a[i], b[i]] }
        },
      ))

      @globals.define("uniq", Builtin.new(
        name: "uniq",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "uniq() expects an array" unless arr.is_a?(Array)
          arr.uniq
        },
      ))

      @globals.define("find", Builtin.new(
        name: "find",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "find() expects an array" unless arr.is_a?(Array)
          arr.find { |item| truthy?(call_function(func, [item])) }
        },
      ))

      @globals.define("find_index", Builtin.new(
        name: "find_index",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "find_index() expects an array" unless arr.is_a?(Array)
          arr.index { |item| truthy?(call_function(func, [item])) }
        },
      ))

      @globals.define("any", Builtin.new(
        name: "any",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "any() expects an array" unless arr.is_a?(Array)
          arr.any? { |item| truthy?(call_function(func, [item])) }
        },
      ))

      @globals.define("all", Builtin.new(
        name: "all",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "all() expects an array" unless arr.is_a?(Array)
          arr.all? { |item| truthy?(call_function(func, [item])) }
        },
      ))

      @globals.define("none", Builtin.new(
        name: "none",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "none() expects an array" unless arr.is_a?(Array)
          arr.none? { |item| truthy?(call_function(func, [item])) }
        },
      ))

      @globals.define("take", Builtin.new(
        name: "take",
        arity: 2,
        body: ->(arr, n) {
          raise Crux::RuntimeError, "take() expects an array and a number" unless arr.is_a?(Array) && n.is_a?(Integer)
          arr.take(n)
        },
      ))

      @globals.define("drop", Builtin.new(
        name: "drop",
        arity: 2,
        body: ->(arr, n) {
          raise Crux::RuntimeError, "drop() expects an array and a number" unless arr.is_a?(Array) && n.is_a?(Integer)
          arr.drop(n)
        },
      ))

      @globals.define("flat_map", Builtin.new(
        name: "flat_map",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "flat_map() expects an array" unless arr.is_a?(Array)
          arr.flat_map { |item|
            result = call_function(func, [item])
            result.is_a?(Array) ? result : [result]
          }
        },
      ))

      @globals.define("sum", Builtin.new(
        name: "sum",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "sum() expects an array" unless arr.is_a?(Array)
          arr.each { |v| check_number(v, "sum") }
          arr.sum
        },
      ))

      @globals.define("enumerate", Builtin.new(
        name: "enumerate",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "enumerate() expects an array" unless arr.is_a?(Array)
          arr.each_with_index.map { |item, i| [i, item] }
        },
      ))

      @globals.define("compact", Builtin.new(
        name: "compact",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "compact() expects an array" unless arr.is_a?(Array)
          arr.compact
        },
      ))

      @globals.define("includes", Builtin.new(
        name: "includes",
        arity: 2,
        body: ->(arr, val) {
          raise Crux::RuntimeError, "includes() expects an array" unless arr.is_a?(Array)
          arr.include?(val)
        },
      ))

      @globals.define("chunk", Builtin.new(
        name: "chunk",
        arity: 2,
        body: ->(arr, size) {
          raise Crux::RuntimeError, "chunk() expects an array and a positive number" unless arr.is_a?(Array) && size.is_a?(Integer) && size > 0
          arr.each_slice(size).to_a
        },
      ))

      @globals.define("min_of", Builtin.new(
        name: "min_of",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "min_of() expects a non-empty array" unless arr.is_a?(Array) && !arr.empty?
          arr.min
        },
      ))

      @globals.define("max_of", Builtin.new(
        name: "max_of",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "max_of() expects a non-empty array" unless arr.is_a?(Array) && !arr.empty?
          arr.max
        },
      ))

      @globals.define("sort_by", Builtin.new(
        name: "sort_by",
        arity: 2,
        body: ->(arr, func) {
          raise Crux::RuntimeError, "sort_by() expects an array" unless arr.is_a?(Array)
          arr.sort_by { |item| call_function(func, [item]) }
        },
      ))
    end

    def register_hash_builtins
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

      @globals.define("delete_key", Builtin.new(
        name: "delete_key",
        arity: 2,
        body: ->(h, k) {
          raise Crux::RuntimeError, "delete_key() expects a hash" unless h.is_a?(Hash)
          h.delete(k)
        },
      ))

      @globals.define("each_entry", Builtin.new(
        name: "each_entry",
        arity: 2,
        body: ->(h, func) {
          raise Crux::RuntimeError, "each_entry() expects a hash" unless h.is_a?(Hash)
          h.each { |k, v| call_function(func, [k, v]) }
          nil
        },
      ))

      @globals.define("map_values", Builtin.new(
        name: "map_values",
        arity: 2,
        body: ->(h, func) {
          raise Crux::RuntimeError, "map_values() expects a hash" unless h.is_a?(Hash)
          h.transform_values { |v| call_function(func, [v]) }
        },
      ))

      @globals.define("filter_entries", Builtin.new(
        name: "filter_entries",
        arity: 2,
        body: ->(h, func) {
          raise Crux::RuntimeError, "filter_entries() expects a hash" unless h.is_a?(Hash)
          h.select { |k, v| truthy?(call_function(func, [k, v])) }
        },
      ))

      @globals.define("get", Builtin.new(
        name: "get",
        arity: 3,
        body: ->(h, k, default) {
          raise Crux::RuntimeError, "get() expects a hash" unless h.is_a?(Hash)
          h.key?(k) ? h[k] : default
        },
      ))

      @globals.define("from_pairs", Builtin.new(
        name: "from_pairs",
        arity: 1,
        body: ->(arr) {
          raise Crux::RuntimeError, "from_pairs() expects an array of pairs" unless arr.is_a?(Array)
          arr.each_with_object({}) do |pair, hash|
            raise Crux::RuntimeError, "from_pairs() each element must be a [key, value] pair" unless pair.is_a?(Array) && pair.length == 2
            hash[pair[0]] = pair[1]
          end
        },
      ))

      @globals.define("to_pairs", Builtin.new(
        name: "to_pairs",
        arity: 1,
        body: ->(h) {
          raise Crux::RuntimeError, "to_pairs() expects a hash" unless h.is_a?(Hash)
          h.map { |k, v| [k, v] }
        },
      ))
    end

    def register_math_builtins
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

      @globals.define("sin", Builtin.new(
        name: "sin",
        arity: 1,
        body: ->(n) {
          check_number(n, "sin")
          Math.sin(n)
        },
      ))

      @globals.define("cos", Builtin.new(
        name: "cos",
        arity: 1,
        body: ->(n) {
          check_number(n, "cos")
          Math.cos(n)
        },
      ))

      @globals.define("tan", Builtin.new(
        name: "tan",
        arity: 1,
        body: ->(n) {
          check_number(n, "tan")
          Math.tan(n)
        },
      ))

      @globals.define("asin", Builtin.new(
        name: "asin",
        arity: 1,
        body: ->(n) {
          check_number(n, "asin")
          Math.asin(n)
        },
      ))

      @globals.define("acos", Builtin.new(
        name: "acos",
        arity: 1,
        body: ->(n) {
          check_number(n, "acos")
          Math.acos(n)
        },
      ))

      @globals.define("atan", Builtin.new(
        name: "atan",
        arity: 1,
        body: ->(n) {
          check_number(n, "atan")
          Math.atan(n)
        },
      ))

      @globals.define("log", Builtin.new(
        name: "log",
        arity: 1,
        body: ->(n) {
          check_number(n, "log")
          raise Crux::RuntimeError, "log() domain error: argument must be positive" unless n > 0
          Math.log(n)
        },
      ))

      @globals.define("log10", Builtin.new(
        name: "log10",
        arity: 1,
        body: ->(n) {
          check_number(n, "log10")
          raise Crux::RuntimeError, "log10() domain error: argument must be positive" unless n > 0
          Math.log10(n)
        },
      ))
    end

    def register_utility_builtins
      @globals.define("clamp", Builtin.new(
        name: "clamp",
        arity: 3,
        body: ->(val, lo, hi) {
          check_number(val, "clamp")
          check_number(lo, "clamp")
          check_number(hi, "clamp")
          val.clamp(lo, hi)
        },
      ))

      @globals.define("sign", Builtin.new(
        name: "sign",
        arity: 1,
        body: ->(n) {
          check_number(n, "sign")
          n <=> 0
        },
      ))

      @globals.define("assert", Builtin.new(
        name: "assert",
        arity: 2,
        body: ->(cond, msg) {
          raise Crux::UserError, stringify(msg) unless truthy?(cond)
          nil
        },
      ))

      @globals.define("time", Builtin.new(
        name: "time",
        arity: 0,
        body: -> { Time.now.to_f },
      ))

      @globals.define("inspect", Builtin.new(
        name: "inspect",
        arity: 1,
        body: ->(val) {
          case val
          when nil then "nil"
          when true then "true"
          when false then "false"
          when Integer then val.to_s
          when Float then val.to_s
          when String then "\"#{val}\""
          when Array then "[#{val.map { |v| call_function(@globals.fetch("inspect"), [v]) }.join(", ")}]"
          when Hash then "{#{val.map { |k, v| "#{call_function(@globals.fetch("inspect"), [k])}: #{call_function(@globals.fetch("inspect"), [v])}" }.join(", ")}}"
          when Closure
            all_params = val.params.dup
            all_params << "...#{val.rest_param}" if val.rest_param
            "<fn(#{all_params.join(", ")})>"
          when Builtin then "<builtin:#{val.name}>"
          else val.to_s
          end
        },
      ))

      @globals.define("is", Builtin.new(
        name: "is",
        arity: 2,
        body: ->(val, type_str) {
          raise Crux::RuntimeError, "is() expects a type string" unless type_str.is_a?(String)
          case type_str
          when "number" then val.is_a?(Numeric)
          when "string" then val.is_a?(String)
          when "array" then val.is_a?(Array)
          when "hash" then val.is_a?(Hash)
          when "boolean" then val == true || val == false
          when "nil" then val.nil?
          when "function" then val.is_a?(Closure) || val.is_a?(Builtin)
          else raise Crux::RuntimeError, "is() unknown type: #{type_str}"
          end
        },
      ))

      @globals.define("apply", Builtin.new(
        name: "apply",
        arity: 2,
        body: ->(func, args_arr) {
          raise Crux::RuntimeError, "apply() expects a function and an array" unless args_arr.is_a?(Array)
          call_function(func, args_arr)
        },
      ))
    end
  end
end
