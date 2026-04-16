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

  # -- New string builtins -------------------------------------------------

  def test_starts_with
    assert_equal true, eval_crux('starts_with("hello", "hel")')
    assert_equal false, eval_crux('starts_with("hello", "world")')
  end

  def test_ends_with
    assert_equal true, eval_crux('ends_with("hello", "llo")')
    assert_equal false, eval_crux('ends_with("hello", "hel")')
  end

  def test_pad_left
    assert_equal "00042", eval_crux('pad_left("42", 5, "0")')
    assert_equal "42", eval_crux('pad_left("42", 2, "0")')
  end

  def test_pad_right
    assert_equal "42000", eval_crux('pad_right("42", 5, "0")')
    assert_equal "hi", eval_crux('pad_right("hi", 1, " ")')
  end

  def test_index_of_string
    assert_equal 2, eval_crux('index_of("hello", "llo")')
    assert_equal(-1, eval_crux('index_of("hello", "xyz")'))
  end

  def test_index_of_array
    assert_equal 1, eval_crux("index_of([10, 20, 30], 20)")
    assert_equal(-1, eval_crux("index_of([10, 20, 30], 99)"))
  end

  def test_repeat_string
    assert_equal "hahaha", eval_crux('repeat("ha", 3)')
  end

  def test_repeat_array
    assert_equal [1, 2, 1, 2], eval_crux("repeat([1, 2], 2)")
  end

  def test_count_string
    assert_equal 3, eval_crux('count("banana", "a")')
  end

  def test_count_array_value
    assert_equal 2, eval_crux("count([1, 2, 3, 2], 2)")
  end

  def test_count_array_predicate
    code = <<~CRUX
      let even = fn(x) -> x % 2 == 0
      count([1, 2, 3, 4, 5, 6], even)
    CRUX
    assert_equal 3, eval_crux(code)
  end

  def test_reverse_string
    assert_equal "olleh", eval_crux('reverse("hello")')
  end

  def test_slice_array
    assert_equal [20, 30], eval_crux("slice([10, 20, 30, 40], 1, 2)")
  end

  # -- New array builtins --------------------------------------------------

  def test_flatten
    assert_equal [1, 2, 3, 4], eval_crux("flatten([[1, 2], [3, [4]]])")
  end

  def test_zip
    assert_equal [[1, "a"], [2, "b"]], eval_crux('zip([1, 2, 3], ["a", "b"])')
  end

  def test_uniq
    assert_equal [1, 2, 3], eval_crux("uniq([1, 2, 2, 3, 1])")
  end

  def test_find
    code = <<~CRUX
      let gt3 = fn(x) -> x > 3
      find([1, 2, 3, 4, 5], gt3)
    CRUX
    assert_equal 4, eval_crux(code)
  end

  def test_find_returns_nil_when_not_found
    code = <<~CRUX
      let gt10 = fn(x) -> x > 10
      find([1, 2, 3], gt10)
    CRUX
    assert_nil eval_crux(code)
  end

  def test_find_index
    code = <<~CRUX
      let even = fn(x) -> x % 2 == 0
      find_index([1, 3, 4, 5], even)
    CRUX
    assert_equal 2, eval_crux(code)
  end

  def test_find_index_returns_nil_when_not_found
    code = <<~CRUX
      let neg = fn(x) -> x < 0
      find_index([1, 2, 3], neg)
    CRUX
    assert_nil eval_crux(code)
  end

  def test_any
    code = <<~CRUX
      let even = fn(x) -> x % 2 == 0
      any([1, 3, 4], even)
    CRUX
    assert_equal true, eval_crux(code)
  end

  def test_any_false
    code = <<~CRUX
      let neg = fn(x) -> x < 0
      any([1, 2, 3], neg)
    CRUX
    assert_equal false, eval_crux(code)
  end

  def test_all
    code = <<~CRUX
      let pos = fn(x) -> x > 0
      all([1, 2, 3], pos)
    CRUX
    assert_equal true, eval_crux(code)
  end

  def test_all_false
    code = <<~CRUX
      let pos = fn(x) -> x > 0
      all([1, -1, 3], pos)
    CRUX
    assert_equal false, eval_crux(code)
  end

  def test_none
    code = <<~CRUX
      let neg = fn(x) -> x < 0
      none([1, 2, 3], neg)
    CRUX
    assert_equal true, eval_crux(code)
  end

  def test_none_false
    code = <<~CRUX
      let neg = fn(x) -> x < 0
      none([1, -2, 3], neg)
    CRUX
    assert_equal false, eval_crux(code)
  end

  def test_take
    assert_equal [1, 2], eval_crux("take([1, 2, 3, 4], 2)")
  end

  def test_drop
    assert_equal [3, 4], eval_crux("drop([1, 2, 3, 4], 2)")
  end

  def test_flat_map
    code = <<~CRUX
      let expand = fn(x) -> [x, x * 2]
      flat_map([1, 2, 3], expand)
    CRUX
    assert_equal [1, 2, 2, 4, 3, 6], eval_crux(code)
  end

  def test_sum
    assert_equal 10, eval_crux("sum([1, 2, 3, 4])")
  end

  def test_sum_empty
    assert_equal 0, eval_crux("sum([])")
  end

  def test_enumerate
    assert_equal [[0, "a"], [1, "b"], [2, "c"]], eval_crux('enumerate(["a", "b", "c"])')
  end

  def test_compact
    assert_equal [1, 2, 3], eval_crux("compact([1, nil, 2, nil, 3])")
  end

  def test_includes
    assert_equal true, eval_crux("includes([1, 2, 3], 2)")
    assert_equal false, eval_crux("includes([1, 2, 3], 99)")
  end

  def test_chunk
    assert_equal [[1, 2], [3, 4], [5]], eval_crux("chunk([1, 2, 3, 4, 5], 2)")
  end

  def test_min_of
    assert_equal 1, eval_crux("min_of([3, 1, 2])")
  end

  def test_max_of
    assert_equal 3, eval_crux("max_of([3, 1, 2])")
  end

  def test_sort_by
    code = <<~CRUX
      let neg = fn(x) -> 0 - x
      sort_by([1, 3, 2], neg)
    CRUX
    assert_equal [3, 2, 1], eval_crux(code)
  end

  # -- New hash builtins ---------------------------------------------------

  def test_delete_key
    code = <<~CRUX
      let h = {"a": 1, "b": 2}
      let val = delete_key(h, "a")
      val
    CRUX
    assert_equal 1, eval_crux(code)
  end

  def test_delete_key_mutates
    code = <<~CRUX
      let h = {"a": 1, "b": 2}
      delete_key(h, "a")
      has_key(h, "a")
    CRUX
    assert_equal false, eval_crux(code)
  end

  def test_each_entry
    code = <<~CRUX
      let result = []
      each_entry({"a": 1, "b": 2}, fn(k, v) -> push(result, k))
      len(result)
    CRUX
    assert_equal 2, eval_crux(code)
  end

  def test_map_values
    code = <<~CRUX
      let h = {"a": 1, "b": 2}
      let doubled = map_values(h, fn(v) -> v * 2)
      doubled["a"]
    CRUX
    assert_equal 2, eval_crux(code)
  end

  def test_filter_entries
    code = <<~CRUX
      let h = {"a": 1, "b": 2, "c": 3}
      let big = filter_entries(h, fn(k, v) -> v > 1)
      len(big)
    CRUX
    assert_equal 2, eval_crux(code)
  end

  def test_get_with_existing_key
    assert_equal 1, eval_crux('get({"a": 1}, "a", 99)')
  end

  def test_get_with_missing_key
    assert_equal 99, eval_crux('get({"a": 1}, "b", 99)')
  end

  def test_from_pairs
    code = <<~CRUX
      let h = from_pairs([["a", 1], ["b", 2]])
      h["a"]
    CRUX
    assert_equal 1, eval_crux(code)
  end

  def test_to_pairs
    code = <<~CRUX
      let h = {"x": 10}
      let pairs = to_pairs(h)
      first(first(pairs))
    CRUX
    assert_equal "x", eval_crux(code)
  end

  # -- New math builtins ---------------------------------------------------

  def test_sin
    assert_in_delta 0.0, eval_crux("sin(0)"), 0.0001
  end

  def test_cos
    assert_in_delta 1.0, eval_crux("cos(0)"), 0.0001
  end

  def test_tan
    assert_in_delta 0.0, eval_crux("tan(0)"), 0.0001
  end

  def test_asin
    assert_in_delta 0.0, eval_crux("asin(0)"), 0.0001
  end

  def test_acos
    assert_in_delta 0.0, eval_crux("acos(1)"), 0.0001
  end

  def test_atan
    assert_in_delta 0.0, eval_crux("atan(0)"), 0.0001
  end

  def test_log
    assert_in_delta 0.0, eval_crux("log(1)"), 0.0001
    assert_in_delta 1.0, eval_crux("log(to_float(2718281828) / 1000000000)"), 0.01
  end

  def test_log_domain_error
    assert_raises(Crux::RuntimeError) { eval_crux("log(0)") }
    assert_raises(Crux::RuntimeError) { eval_crux("log(-1)") }
  end

  def test_log10
    assert_in_delta 2.0, eval_crux("log10(100)"), 0.0001
    assert_in_delta 1.0, eval_crux("log10(10)"), 0.0001
  end

  # -- New utility builtins ------------------------------------------------

  def test_clamp
    assert_equal 5, eval_crux("clamp(5, 0, 10)")
    assert_equal 0, eval_crux("clamp(-3, 0, 10)")
    assert_equal 10, eval_crux("clamp(15, 0, 10)")
  end

  def test_sign
    assert_equal 1, eval_crux("sign(42)")
    assert_equal(-1, eval_crux("sign(-7)"))
    assert_equal 0, eval_crux("sign(0)")
  end

  def test_assert_success
    assert_nil eval_crux('assert(true, "should not fail")')
  end

  def test_assert_failure
    assert_raises(Crux::UserError) { eval_crux('assert(false, "boom")') }
  end

  def test_time
    result = eval_crux("time()")
    assert_kind_of Float, result
    assert result > 0
  end

  def test_inspect_values
    assert_equal '"hello"', eval_crux('inspect("hello")')
    assert_equal "42", eval_crux("inspect(42)")
    assert_equal "nil", eval_crux("inspect(nil)")
    assert_equal "true", eval_crux("inspect(true)")
  end

  def test_inspect_array
    assert_equal '[1, "a"]', eval_crux('inspect([1, "a"])')
  end

  def test_is
    assert_equal true, eval_crux('is(42, "number")')
    assert_equal true, eval_crux('is(3.14, "number")')
    assert_equal true, eval_crux('is("hi", "string")')
    assert_equal true, eval_crux('is([1], "array")')
    assert_equal true, eval_crux('is({"a": 1}, "hash")')
    assert_equal true, eval_crux('is(true, "boolean")')
    assert_equal true, eval_crux('is(nil, "nil")')
    assert_equal true, eval_crux('is(fn() -> 1, "function")')
    assert_equal false, eval_crux('is(42, "string")')
  end

  def test_is_builtin_is_function
    assert_equal true, eval_crux('is(print, "function")')
  end

  def test_apply
    code = <<~CRUX
      let add = fn(a, b) -> a + b
      apply(add, [3, 4])
    CRUX
    assert_equal 7, eval_crux(code)
  end

  def test_apply_builtin
    assert_equal 5, eval_crux("apply(abs, [-5])")
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

  # == Group A: Compound Assignment Operators (1-5) ==========================

  def test_plus_equal
    assert_equal 15, eval_crux("let x = 10\nx += 5\nx")
  end

  def test_minus_equal
    assert_equal 5, eval_crux("let x = 10\nx -= 5\nx")
  end

  def test_star_equal
    assert_equal 30, eval_crux("let x = 10\nx *= 3\nx")
  end

  def test_slash_equal
    assert_equal 5, eval_crux("let x = 10\nx /= 2\nx")
  end

  def test_percent_equal
    assert_equal 1, eval_crux("let x = 10\nx %= 3\nx")
  end

  def test_compound_assign_index
    code = <<~CRUX
      let arr = [10, 20, 30]
      arr[1] += 5
      arr[1]
    CRUX
    assert_equal 25, eval_crux(code)
  end

  # == Group B: Number Literal Formats (6-10) ===============================

  def test_hex_literal
    assert_equal 255, eval_crux("0xFF")
    assert_equal 255, eval_crux("0XFF")
  end

  def test_binary_literal
    assert_equal 10, eval_crux("0b1010")
    assert_equal 10, eval_crux("0B1010")
  end

  def test_octal_literal
    assert_equal 63, eval_crux("0o77")
    assert_equal 63, eval_crux("0O77")
  end

  def test_scientific_notation
    assert_in_delta 1500.0, eval_crux("1.5e3")
    assert_in_delta 0.01, eval_crux("1e-2")
    assert_in_delta 100.0, eval_crux("1E2")
  end

  def test_underscore_separator
    assert_equal 1000000, eval_crux("1_000_000")
    assert_equal 255, eval_crux("0xFF_FF".gsub("FF_FF", "FF"))
  end

  # == Group C: Control Flow (11-15) ========================================

  def test_unless
    assert_equal 42, eval_crux("unless false then 42 end")
    assert_nil eval_crux("unless true then 42 end")
  end

  def test_until_loop
    code = <<~CRUX
      let x = 0
      until x >= 5 do
        x += 1
      end
      x
    CRUX
    assert_equal 5, eval_crux(code)
  end

  def test_loop_with_break
    code = <<~CRUX
      let x = 0
      loop do
        x += 1
        if x == 5 then break end
      end
      x
    CRUX
    assert_equal 5, eval_crux(code)
  end

  def test_break_exits_while
    code = <<~CRUX
      let x = 0
      while true do
        x += 1
        if x == 3 then break end
      end
      x
    CRUX
    assert_equal 3, eval_crux(code)
  end

  def test_break_with_value
    code = <<~CRUX
      let result = while true do
        break 42
      end
      result
    CRUX
    assert_equal 42, eval_crux(code)
  end

  def test_continue_skips_iteration
    code = <<~CRUX
      let sum = 0
      for i in range(1, 6) do
        if i == 3 then continue end
        sum += i
      end
      sum
    CRUX
    assert_equal 12, eval_crux(code) # 1+2+4+5 = 12
  end

  # == Group D: New Operators (16-20) =======================================

  def test_nil_coalescing
    assert_equal 42, eval_crux("nil ?? 42")
    assert_equal 10, eval_crux("10 ?? 42")
    assert_equal false, eval_crux("false ?? 42") # false is not nil
  end

  def test_exponent_operator
    assert_equal 1024, eval_crux("2 ** 10")
    assert_equal 8, eval_crux("2 ** 3")
  end

  def test_exponent_right_associative
    assert_equal 512, eval_crux("2 ** 3 ** 2") # 2^(3^2) = 2^9 = 512
  end

  def test_string_repeat_operator
    assert_equal "hahaha", eval_crux('"ha" * 3')
  end

  def test_array_repeat_operator
    assert_equal [1, 2, 1, 2, 1, 2], eval_crux("[1, 2] * 3")
  end

  def test_spaceship_operator
    assert_equal(-1, eval_crux("1 <=> 2"))
    assert_equal 0, eval_crux("5 <=> 5")
    assert_equal 1, eval_crux("3 <=> 1")
  end

  # == Group E: Function Composition (21-22) ================================

  def test_compose_right
    code = <<~CRUX
      let double = fn(x) -> x * 2
      let inc = fn(x) -> x + 1
      let f = double >> inc
      f(5)
    CRUX
    assert_equal 11, eval_crux(code) # inc(double(5)) = inc(10) = 11
  end

  def test_compose_left
    code = <<~CRUX
      let double = fn(x) -> x * 2
      let inc = fn(x) -> x + 1
      let f = double << inc
      f(5)
    CRUX
    assert_equal 12, eval_crux(code) # double(inc(5)) = double(6) = 12
  end

  # == Group F: Function Enhancements (23-24) ===============================

  def test_default_params
    code = <<~CRUX
      let greet = fn(name, greeting = "Hello") -> greeting + ", " + name
      greet("world")
    CRUX
    assert_equal "Hello, world", eval_crux(code)
  end

  def test_default_params_override
    code = <<~CRUX
      let greet = fn(name, greeting = "Hello") -> greeting + ", " + name
      greet("world", "Hi")
    CRUX
    assert_equal "Hi, world", eval_crux(code)
  end

  def test_return_statement
    code = <<~CRUX
      let f = fn(x) -> do
        if x > 0 then return x * 2 end
        return 0 - x
      end
      f(5)
    CRUX
    assert_equal 10, eval_crux(code)
  end

  def test_return_early_exit
    code = <<~CRUX
      let f = fn(x) -> do
        return 42
        99
      end
      f(0)
    CRUX
    assert_equal 42, eval_crux(code)
  end

  # == Group G: Pattern Matching (25-27) ====================================

  def test_match_literal
    code = <<~CRUX
      let x = 2
      match x
        when 1 -> "one"
        when 2 -> "two"
        when 3 -> "three"
      end
    CRUX
    assert_equal "two", eval_crux(code)
  end

  def test_match_wildcard
    code = <<~CRUX
      match 99
        when 1 -> "one"
        when _ -> "other"
      end
    CRUX
    assert_equal "other", eval_crux(code)
  end

  def test_match_with_guard
    code = <<~CRUX
      let x = 15
      match x
        when n if n > 10 -> "big"
        when _ -> "small"
      end
    CRUX
    assert_equal "big", eval_crux(code)
  end

  def test_match_no_match_returns_nil
    code = <<~CRUX
      match 5
        when 1 -> "one"
        when 2 -> "two"
      end
    CRUX
    assert_nil eval_crux(code)
  end

  def test_match_variable_binding
    code = <<~CRUX
      match 42
        when val -> val * 2
      end
    CRUX
    assert_equal 84, eval_crux(code)
  end

  # == Group H: Array Destructuring (28-30) =================================

  def test_let_destructure
    code = <<~CRUX
      let [a, b, c] = [1, 2, 3]
      a + b + c
    CRUX
    assert_equal 6, eval_crux(code)
  end

  def test_let_destructure_with_rest
    code = <<~CRUX
      let [head, ...tail] = [1, 2, 3, 4]
      tail
    CRUX
    assert_equal [2, 3, 4], eval_crux(code)
  end

  def test_for_in_destructure
    code = <<~CRUX
      let h = {"a": 1, "b": 2}
      let sum = 0
      for [k, v] in to_pairs(h) do
        sum += v
      end
      sum
    CRUX
    assert_equal 3, eval_crux(code)
  end

  # == Group I: String Enhancements (31-32) =================================

  def test_carriage_return_escape
    result = eval_crux('"hello\r"')
    assert_equal "hello\r", result
  end

  def test_null_byte_escape
    result = eval_crux('"hello\0"')
    assert_equal "hello\0", result
  end

  # == Group J: Dot Method Syntax (33) ======================================

  def test_dot_method_syntax
    assert_equal 3, eval_crux("[1, 2, 3].len()")
  end

  def test_dot_method_chaining
    code = <<~CRUX
      let arr = [3, 1, 2]
      arr.sort().reverse()
    CRUX
    assert_equal [3, 2, 1], eval_crux(code)
  end

  def test_dot_method_with_args
    assert_equal "a-b-c", eval_crux('["a", "b", "c"].join("-")')
  end

  # == Group K: Postfix Conditionals (34-35) ================================

  def test_postfix_if
    assert_equal 42, eval_crux("42 if true")
    assert_nil eval_crux("42 if false")
  end

  def test_postfix_unless
    assert_equal 42, eval_crux("42 unless false")
    assert_nil eval_crux("42 unless true")
  end

  # == Group L: Const Bindings (36) =========================================

  def test_const_binding
    assert_equal 42, eval_crux("const X = 42\nX")
  end

  def test_const_reassign_raises
    assert_raises(Crux::RuntimeError) { eval_crux("const X = 42\nX = 99") }
  end

  # == Group M: Trailing Commas (37-40) =====================================

  def test_trailing_comma_array
    assert_equal [1, 2, 3], eval_crux("[1, 2, 3,]")
  end

  def test_trailing_comma_hash
    result = eval_crux('{"a": 1, "b": 2,}')
    assert_equal({"a" => 1, "b" => 2}, result)
  end

  def test_trailing_comma_fn_params
    assert_equal 3, eval_crux("let f = fn(a, b,) -> a + b\nf(1, 2)")
  end

  def test_trailing_comma_fn_call
    assert_equal 3, eval_crux("let f = fn(a, b) -> a + b\nf(1, 2,)")
  end

  # == Group N: Global Constants (41-44) ====================================

  def test_pi_constant
    assert_in_delta Math::PI, eval_crux("PI"), 0.0001
  end

  def test_e_constant
    assert_in_delta Math::E, eval_crux("E"), 0.0001
  end

  def test_infinity_constant
    assert_equal Float::INFINITY, eval_crux("INFINITY")
  end

  def test_nan_constant
    result = eval_crux("NAN")
    assert result.is_a?(Float)
    assert result.nan?
  end

  # == Group O: Miscellaneous (45-50) =======================================

  def test_range_with_step
    assert_equal [0, 2, 4, 6, 8], eval_crux("range(0, 10, 2)")
  end

  def test_range_negative_step
    assert_equal [10, 8, 6, 4, 2], eval_crux("range(10, 0, -2)")
  end

  def test_array_concat_operator
    assert_equal [1, 2, 3, 4], eval_crux("[1, 2] + [3, 4]")
  end

  def test_finally_clause
    code = <<~CRUX
      let log = []
      try
        push(log, "body")
        throw "oops"
      catch e ->
        push(log, "catch")
      finally ->
        push(log, "finally")
      end
      log
    CRUX
    assert_equal ["body", "catch", "finally"], eval_crux(code)
  end

  def test_finally_runs_on_success
    code = <<~CRUX
      let log = []
      try
        push(log, "body")
      catch e ->
        push(log, "catch")
      finally ->
        push(log, "finally")
      end
      log
    CRUX
    assert_equal ["body", "finally"], eval_crux(code)
  end

  def test_multiline_array
    code = <<~CRUX
      let arr = [
        1,
        2,
        3
      ]
      arr
    CRUX
    assert_equal [1, 2, 3], eval_crux(code)
  end

  def test_multiline_hash
    code = <<~CRUX
      let h = {
        "a": 1,
        "b": 2,
        "c": 3
      }
      len(h)
    CRUX
    assert_equal 3, eval_crux(code)
  end

  # == Integration tests for new features ===================================

  def test_compound_assign_in_loop
    code = <<~CRUX
      let total = 0
      for i in range(1, 11) do
        total += i
      end
      total
    CRUX
    assert_equal 55, eval_crux(code)
  end

  def test_nil_coalescing_chain
    code = <<~CRUX
      let a = nil
      let b = nil
      let c = 42
      a ?? b ?? c
    CRUX
    assert_equal 42, eval_crux(code)
  end

  def test_match_string_patterns
    code = <<~CRUX
      let classify = fn(status) -> match status
        when "active" -> "running"
        when "paused" -> "suspended"
        when _ -> "unknown"
      end
      classify("paused")
    CRUX
    assert_equal "suspended", eval_crux(code)
  end

  def test_exponent_precedence
    # ** should bind tighter than *
    assert_equal 24, eval_crux("3 * 2 ** 3") # 3 * 8 = 24
  end

  def test_dot_method_no_parens
    # dot method without parens should still work (no-arg call)
    assert_equal [3, 2, 1], eval_crux("[1, 2, 3].sort().reverse()")
  end

  private

  def eval_crux(source)
    output = StringIO.new
    tokens = Crux::Lexer.new(source).tokenize
    ast = Crux::Parser.new(tokens).parse
    Crux::Interpreter.new(output: output).evaluate(ast)
  end
end
