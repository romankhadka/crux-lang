# frozen_string_literal: true

require_relative "test_helper"

class InterpreterTest < Minitest::Test
  # -- Literals ------------------------------------------------------------

  def test_integer
    assert_equal 42, eval_crux("42")
  end

  def test_float
    assert_equal 3.14, eval_crux("3.14")
  end

  def test_string
    assert_equal "hello", eval_crux('"hello"')
  end

  def test_boolean_true
    assert_equal true, eval_crux("true")
  end

  def test_boolean_false
    assert_equal false, eval_crux("false")
  end

  def test_nil
    assert_nil eval_crux("nil")
  end

  # -- Arithmetic ----------------------------------------------------------

  def test_addition
    assert_equal 7, eval_crux("3 + 4")
  end

  def test_subtraction
    assert_equal 1, eval_crux("5 - 4")
  end

  def test_multiplication
    assert_equal 12, eval_crux("3 * 4")
  end

  def test_integer_division
    assert_equal 3, eval_crux("7 / 2")
  end

  def test_float_division
    assert_equal 3.5, eval_crux("7.0 / 2")
  end

  def test_modulo
    assert_equal 1, eval_crux("7 % 3")
  end

  def test_unary_minus
    assert_equal(-5, eval_crux("-5"))
  end

  def test_operator_precedence
    assert_equal 11, eval_crux("1 + 2 * 5")
  end

  def test_grouping
    assert_equal 15, eval_crux("(1 + 2) * 5")
  end

  def test_string_concatenation
    assert_equal "hello world", eval_crux('"hello " + "world"')
  end

  def test_division_by_zero
    assert_raises(Crux::RuntimeError) { eval_crux("1 / 0") }
  end

  def test_type_mismatch_arithmetic
    assert_raises(Crux::RuntimeError) { eval_crux('"a" + 1') }
  end

  # -- Comparison ----------------------------------------------------------

  def test_equality
    assert_equal true, eval_crux("1 == 1")
    assert_equal false, eval_crux("1 == 2")
  end

  def test_inequality
    assert_equal true, eval_crux("1 != 2")
    assert_equal false, eval_crux("1 != 1")
  end

  def test_less_than
    assert_equal true, eval_crux("1 < 2")
    assert_equal false, eval_crux("2 < 1")
  end

  def test_greater_than
    assert_equal true, eval_crux("2 > 1")
    assert_equal false, eval_crux("1 > 2")
  end

  def test_less_equal
    assert_equal true, eval_crux("1 <= 1")
    assert_equal true, eval_crux("1 <= 2")
  end

  def test_greater_equal
    assert_equal true, eval_crux("2 >= 2")
    assert_equal true, eval_crux("3 >= 2")
  end

  def test_string_comparison
    assert_equal true, eval_crux('"a" < "b"')
  end

  # -- Logic ---------------------------------------------------------------

  def test_and_short_circuits
    assert_equal false, eval_crux("false and true")
    assert_equal 2, eval_crux("1 and 2")
  end

  def test_or_short_circuits
    assert_equal 1, eval_crux("1 or 2")
    assert_equal 2, eval_crux("false or 2")
  end

  def test_not
    assert_equal true, eval_crux("not false")
    assert_equal false, eval_crux("not true")
    assert_equal false, eval_crux("not 1")
  end

  # -- Variables -----------------------------------------------------------

  def test_let_and_reference
    assert_equal 42, eval_crux("let x = 42\nx")
  end

  def test_assignment
    assert_equal 10, eval_crux("let x = 5\nx = 10\nx")
  end

  def test_undefined_variable
    assert_raises(Crux::RuntimeError) { eval_crux("x") }
  end

  def test_assign_undefined_variable
    assert_raises(Crux::RuntimeError) { eval_crux("x = 5") }
  end

  # -- Functions -----------------------------------------------------------

  def test_simple_function
    assert_equal 7, eval_crux("let add = fn(a, b) -> a + b\nadd(3, 4)")
  end

  def test_zero_arity_function
    assert_equal 42, eval_crux("let f = fn() -> 42\nf()")
  end

  def test_wrong_arity
    assert_raises(Crux::RuntimeError) { eval_crux("let f = fn(x) -> x\nf(1, 2)") }
  end

  def test_higher_order_function
    code = <<~CRUX
      let apply = fn(f, x) -> f(x)
      let double = fn(x) -> x * 2
      apply(double, 5)
    CRUX
    assert_equal 10, eval_crux(code)
  end

  def test_immediately_invoked_function
    assert_equal 42, eval_crux("(fn() -> 42)()")
  end

  # -- Closures ------------------------------------------------------------

  def test_closure_captures_environment
    code = <<~CRUX
      let make_adder = fn(n) -> fn(x) -> x + n
      let add5 = make_adder(5)
      add5(10)
    CRUX
    assert_equal 15, eval_crux(code)
  end

  def test_closure_mutates_captured_variable
    code = <<~CRUX
      let counter = fn() -> do
        let count = 0
        fn() -> do
          count = count + 1
          count
        end
      end
      let c = counter()
      c()
      c()
      c()
    CRUX
    assert_equal 3, eval_crux(code)
  end

  # -- Recursion -----------------------------------------------------------

  def test_recursion_fibonacci
    code = <<~CRUX
      let fib = fn(n) ->
        if n <= 1 then n
        else fib(n - 1) + fib(n - 2) end

      fib(10)
    CRUX
    assert_equal 55, eval_crux(code)
  end

  def test_recursion_factorial
    code = <<~CRUX
      let fact = fn(n) ->
        if n <= 1 then 1
        else n * fact(n - 1) end

      fact(6)
    CRUX
    assert_equal 720, eval_crux(code)
  end

  # -- Control flow --------------------------------------------------------

  def test_if_then
    assert_equal 1, eval_crux("if true then 1 end")
  end

  def test_if_then_else
    assert_equal 2, eval_crux("if false then 1 else 2 end")
  end

  def test_if_nil_when_false_and_no_else
    assert_nil eval_crux("if false then 1 end")
  end

  def test_while_loop
    code = <<~CRUX
      let sum = 0
      let i = 1
      while i <= 10 do
        sum = sum + i
        i = i + 1
      end
      sum
    CRUX
    assert_equal 55, eval_crux(code)
  end

  # -- Error handling ------------------------------------------------------

  def test_try_catch_catches_runtime_error
    code = <<~CRUX
      try
        1 / 0
      catch e ->
        "caught: " + e
      end
    CRUX
    assert_equal "caught: Division by zero", eval_crux(code)
  end

  def test_try_catch_returns_body_on_success
    code = <<~CRUX
      try
        42
      catch e ->
        0
      end
    CRUX
    assert_equal 42, eval_crux(code)
  end

  def test_throw_and_catch
    code = <<~CRUX
      try
        throw "something went wrong"
      catch e ->
        e
      end
    CRUX
    assert_equal "something went wrong", eval_crux(code)
  end

  def test_throw_uncaught_raises
    assert_raises(Crux::UserError) { eval_crux('throw "boom"') }
  end

  def test_try_catch_in_function
    code = <<~CRUX
      let safe_div = fn(a, b) ->
        try
          a / b
        catch e ->
          0
        end

      safe_div(10, 0)
    CRUX
    assert_equal 0, eval_crux(code)
  end

  # -- Rest parameters -----------------------------------------------------

  def test_rest_params_basic
    code = <<~CRUX
      let f = fn(first, ...rest) -> rest
      f(1, 2, 3, 4)
    CRUX
    assert_equal [2, 3, 4], eval_crux(code)
  end

  def test_rest_params_empty
    code = <<~CRUX
      let f = fn(first, ...rest) -> rest
      f(1)
    CRUX
    assert_equal [], eval_crux(code)
  end

  def test_rest_params_only
    code = <<~CRUX
      let sum_all = fn(...nums) -> reduce(nums, 0, fn(a, b) -> a + b)
      sum_all(1, 2, 3, 4, 5)
    CRUX
    assert_equal 15, eval_crux(code)
  end

  def test_rest_params_too_few_args
    code = <<~CRUX
      let f = fn(a, b, ...rest) -> rest
      f(1)
    CRUX
    assert_raises(Crux::RuntimeError) { eval_crux(code) }
  end

  # -- String interpolation ------------------------------------------------

  def test_basic_interpolation
    code = <<~CRUX
      let name = "world"
      "Hello, ${name}!"
    CRUX
    assert_equal "Hello, world!", eval_crux(code)
  end

  def test_interpolation_with_expression
    assert_equal "2 + 3 = 5", eval_crux('"2 + 3 = ${2 + 3}"')
  end

  def test_interpolation_multiple_parts
    code = <<~CRUX
      let a = "foo"
      let b = "bar"
      "${a} and ${b}"
    CRUX
    assert_equal "foo and bar", eval_crux(code)
  end

  def test_interpolation_nested_braces
    assert_equal "sum=6", eval_crux('"sum=${1 + 2 + 3}"')
  end

  def test_interpolation_escape_dollar
    assert_equal "${x}", eval_crux('"\\${x}"')
  end

  def test_no_interpolation_plain_string
    assert_equal "hello", eval_crux('"hello"')
  end

  # -- Hashmaps ------------------------------------------------------------

  def test_hash_literal
    result = eval_crux('{"name": "Alice", "age": 30}')
    assert_equal({"name" => "Alice", "age" => 30}, result)
  end

  def test_empty_hash
    assert_equal({}, eval_crux("{}"))
  end

  def test_hash_bracket_access
    assert_equal "Alice", eval_crux('{"name": "Alice"}["name"]')
  end

  def test_hash_bracket_assign
    code = <<~CRUX
      let h = {"x": 1}
      h["x"] = 99
      h["x"]
    CRUX
    assert_equal 99, eval_crux(code)
  end

  def test_hash_add_new_key
    code = <<~CRUX
      let h = {}
      h["name"] = "Bob"
      h["name"]
    CRUX
    assert_equal "Bob", eval_crux(code)
  end

  def test_hash_missing_key_returns_nil
    assert_nil eval_crux('{"a": 1}["b"]')
  end

  def test_keys_and_values
    code = <<~CRUX
      let h = {"a": 1, "b": 2}
      len(keys(h))
    CRUX
    assert_equal 2, eval_crux(code)
  end

  def test_has_key
    assert_equal true, eval_crux('has_key({"x": 1}, "x")')
    assert_equal false, eval_crux('has_key({"x": 1}, "y")')
  end

  def test_merge
    code = <<~CRUX
      let a = {"x": 1}
      let b = {"y": 2}
      let c = merge(a, b)
      len(c)
    CRUX
    assert_equal 2, eval_crux(code)
  end

  def test_hash_type
    assert_equal "hash", eval_crux('type({"a": 1})')
  end

  def test_len_on_hash
    assert_equal 2, eval_crux('len({"a": 1, "b": 2})')
  end

  # -- For-in loops --------------------------------------------------------

  def test_for_in_basic
    code = <<~CRUX
      let sum = 0
      for x in [1, 2, 3, 4, 5] do
        sum = sum + x
      end
      sum
    CRUX
    assert_equal 15, eval_crux(code)
  end

  def test_for_in_with_range
    code = <<~CRUX
      let sum = 0
      for i in range(1, 6) do
        sum = sum + i
      end
      sum
    CRUX
    assert_equal 15, eval_crux(code)
  end

  def test_for_in_scoping
    code = <<~CRUX
      for x in [1, 2, 3] do
        x
      end
      x
    CRUX
    assert_raises(Crux::RuntimeError) { eval_crux(code) }
  end

  def test_for_in_returns_last_value
    result = eval_crux("for x in [10, 20, 30] do x * 2 end")
    assert_equal 60, result
  end

  # -- Blocks --------------------------------------------------------------

  def test_block_returns_last_expression
    assert_equal 3, eval_crux("do\n  1\n  2\n  3\nend")
  end

  def test_block_scoping
    code = <<~CRUX
      let x = 1
      do
        let y = 2
        x + y
      end
    CRUX
    assert_equal 3, eval_crux(code)
  end

  def test_block_inner_variable_not_visible_outside
    code = <<~CRUX
      do
        let secret = 42
      end
      secret
    CRUX
    assert_raises(Crux::RuntimeError) { eval_crux(code) }
  end

  # -- Pipes ---------------------------------------------------------------

  def test_simple_pipe
    code = <<~CRUX
      let double = fn(x) -> x * 2
      5 |> double
    CRUX
    assert_equal 10, eval_crux(code)
  end

  def test_chained_pipes
    code = <<~CRUX
      let double = fn(x) -> x * 2
      let square = fn(x) -> x * x
      3 |> double |> square
    CRUX
    assert_equal 36, eval_crux(code)
  end

  def test_pipe_with_extra_arguments
    code = <<~CRUX
      let add = fn(a, b) -> a + b
      5 |> add(10)
    CRUX
    assert_equal 15, eval_crux(code)
  end

  def test_pipe_to_builtin
    output = StringIO.new
    interpreter = Crux::Interpreter.new(output: output)
    tokens = Crux::Lexer.new("42 |> print").tokenize
    ast = Crux::Parser.new(tokens).parse
    interpreter.evaluate(ast)
    assert_equal "42\n", output.string
  end

  # -- Builtins ------------------------------------------------------------

  def test_print
    output = StringIO.new
    interpreter = Crux::Interpreter.new(output: output)
    tokens = Crux::Lexer.new('print("hi")').tokenize
    ast = Crux::Parser.new(tokens).parse
    interpreter.evaluate(ast)
    assert_equal "hi\n", output.string
  end

  def test_str
    assert_equal "42", eval_crux("str(42)")
  end

  def test_len
    assert_equal 5, eval_crux('len("hello")')
  end

  def test_type
    assert_equal "number", eval_crux("type(42)")
    assert_equal "string", eval_crux('type("hi")')
    assert_equal "boolean", eval_crux("type(true)")
    assert_equal "nil", eval_crux("type(nil)")
    assert_equal "function", eval_crux("type(fn() -> 1)")
  end

  def test_abs
    assert_equal 5, eval_crux("abs(-5)")
    assert_equal 5, eval_crux("abs(5)")
  end

  def test_max_and_min
    assert_equal 10, eval_crux("max(3, 10)")
    assert_equal 3, eval_crux("min(3, 10)")
  end

  def test_to_int
    assert_equal 3, eval_crux("to_int(3.7)")
    assert_equal 42, eval_crux('to_int("42")')
  end

  def test_to_float
    assert_in_delta 3.0, eval_crux("to_float(3)")
  end

  # -- Arrays --------------------------------------------------------------

  def test_array_literal
    assert_equal [1, 2, 3], eval_crux("[1, 2, 3]")
  end

  def test_empty_array
    assert_equal [], eval_crux("[]")
  end

  def test_array_index_access
    assert_equal 20, eval_crux("[10, 20, 30][1]")
  end

  def test_array_negative_index
    assert_equal 30, eval_crux("[10, 20, 30][-1]")
  end

  def test_array_index_out_of_bounds
    assert_raises(Crux::RuntimeError) { eval_crux("[1, 2][5]") }
  end

  def test_array_index_assign
    code = <<~CRUX
      let arr = [1, 2, 3]
      arr[1] = 99
      arr[1]
    CRUX
    assert_equal 99, eval_crux(code)
  end

  def test_array_with_expressions
    assert_equal [3, 7], eval_crux("[1 + 2, 3 + 4]")
  end

  def test_len_on_array
    assert_equal 3, eval_crux("len([1, 2, 3])")
  end

  def test_array_type
    assert_equal "array", eval_crux("type([1, 2])")
  end

  def test_nested_arrays
    assert_equal 5, eval_crux("[[1, 2], [3, 4, 5]][1][2]")
  end

  def test_string_index_access
    assert_equal "e", eval_crux('"hello"[1]')
  end

  # -- Array builtins ------------------------------------------------------

  def test_push_and_pop
    code = <<~CRUX
      let arr = [1, 2]
      push(arr, 3)
      pop(arr)
    CRUX
    assert_equal 3, eval_crux(code)
  end

  def test_first_and_last
    assert_equal 1, eval_crux("first([1, 2, 3])")
    assert_equal 3, eval_crux("last([1, 2, 3])")
  end

  def test_reverse
    assert_equal [3, 2, 1], eval_crux("reverse([1, 2, 3])")
  end

  def test_sort
    assert_equal [1, 2, 3], eval_crux("sort([3, 1, 2])")
  end

  def test_join
    assert_equal "a-b-c", eval_crux('join(["a", "b", "c"], "-")')
  end

  def test_map
    code = <<~CRUX
      let double = fn(x) -> x * 2
      map([1, 2, 3], double)
    CRUX
    assert_equal [2, 4, 6], eval_crux(code)
  end

  def test_filter
    code = <<~CRUX
      let even = fn(x) -> x % 2 == 0
      filter([1, 2, 3, 4, 5, 6], even)
    CRUX
    assert_equal [2, 4, 6], eval_crux(code)
  end

  def test_reduce
    code = <<~CRUX
      let add = fn(acc, x) -> acc + x
      reduce([1, 2, 3, 4], 0, add)
    CRUX
    assert_equal 10, eval_crux(code)
  end

  def test_range
    assert_equal [0, 1, 2, 3, 4], eval_crux("range(0, 5)")
  end

  def test_concat
    assert_equal [1, 2, 3, 4], eval_crux("concat([1, 2], [3, 4])")
  end

  def test_empty
    assert_equal true, eval_crux("empty([])")
    assert_equal false, eval_crux("empty([1])")
  end

  def test_map_filter_pipe_chain
    code = <<~CRUX
      let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      let even = fn(x) -> x % 2 == 0
      let double = fn(x) -> x * 2
      let result = filter(map(nums, double), even)
      len(result)
    CRUX
    assert_equal 10, eval_crux(code)
  end

  # -- String builtins -----------------------------------------------------

  def test_upper
    assert_equal "HELLO", eval_crux('upper("hello")')
  end

  def test_lower
    assert_equal "hello", eval_crux('lower("HELLO")')
  end

  def test_trim
    assert_equal "hello", eval_crux('trim("  hello  ")')
  end

  def test_split
    result = eval_crux('split("a,b,c", ",")')
    assert_equal ["a", "b", "c"], result
  end

  def test_replace
    assert_equal "hello world", eval_crux('replace("hello there", "there", "world")')
  end

  def test_contains
    assert_equal true, eval_crux('contains("hello world", "world")')
    assert_equal false, eval_crux('contains("hello world", "xyz")')
  end

  def test_chars
    assert_equal ["a", "b", "c"], eval_crux('chars("abc")')
  end

  def test_slice
    assert_equal "ell", eval_crux('slice("hello", 1, 3)')
  end

  # -- Math builtins -------------------------------------------------------

  def test_floor
    assert_equal 3, eval_crux("floor(3.7)")
    assert_equal 3, eval_crux("floor(3)")
  end

  def test_ceil
    assert_equal 4, eval_crux("ceil(3.1)")
    assert_equal 3, eval_crux("ceil(3)")
  end

  def test_round
    assert_equal 4, eval_crux("round(3.5)")
    assert_in_delta 3.14, eval_crux("round(3.14159, 2)")
  end

  def test_sqrt
    assert_in_delta 3.0, eval_crux("sqrt(9)")
    assert_raises(Crux::RuntimeError) { eval_crux("sqrt(-1)") }
  end

  def test_pow
    assert_equal 8, eval_crux("pow(2, 3)")
    assert_in_delta 1.0, eval_crux("pow(5, 0)")
  end

  def test_random
    result = eval_crux("random()")
    assert_kind_of Float, result
    assert result >= 0.0 && result < 1.0
  end

  # -- Integration ---------------------------------------------------------

  def test_fizzbuzz
    code = <<~CRUX
      let fizzbuzz = fn(n) ->
        if n % 15 == 0 then "FizzBuzz"
        else if n % 3 == 0 then "Fizz"
        else if n % 5 == 0 then "Buzz"
        else str(n) end end end

      fizzbuzz(15)
    CRUX
    assert_equal "FizzBuzz", eval_crux(code)
  end

  def test_compose
    code = <<~CRUX
      let compose = fn(f, g) -> fn(x) -> f(g(x))
      let double = fn(x) -> x * 2
      let inc = fn(x) -> x + 1
      let double_then_inc = compose(inc, double)
      double_then_inc(5)
    CRUX
    assert_equal 11, eval_crux(code)
  end

  private

  def eval_crux(source)
    output = StringIO.new
    tokens = Crux::Lexer.new(source).tokenize
    ast = Crux::Parser.new(tokens).parse
    Crux::Interpreter.new(output: output).evaluate(ast)
  end
end
