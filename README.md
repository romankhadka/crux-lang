# Crux

A tiny programming language with closures, pipes, arrays, hashmaps, and error handling, implemented as a tree-walk interpreter in Ruby.

Crux is an expression-oriented language with first-class functions, lexical closures, a pipe operator (`|>`) for functional composition, and a rich standard library.

## Quick Start

```bash
# Run a program
ruby bin/crux examples/showcase.crux

# Start the REPL
ruby bin/crux
```

## Language Tour

### Variables

```crux
let name = "world"
let x = 42
x = x + 1    # reassignment
```

### String Interpolation

```crux
let name = "world"
print("Hello, ${name}!")        # Hello, world!
print("2 + 2 = ${2 + 2}")      # 2 + 2 = 4
```

### Functions

Functions are first-class values. They close over their defining scope.

```crux
let greet = fn(name) -> "Hello, ${name}"
print(greet("world"))

# Multi-expression bodies use do...end
let max3 = fn(a, b, c) -> do
  let m = if a > b then a else b end
  if m > c then m else c end
end

# Rest parameters collect extra arguments into an array
let log = fn(level, ...messages) ->
  print("[${upper(level)}] ${join(messages, " ")}")

log("info", "server", "started")
```

### Closures

Functions capture their environment. This enables factories, private state, and higher-order patterns.

```crux
let counter = fn() -> do
  let n = 0
  fn() -> do
    n = n + 1
    n
  end
end

let c = counter()
print(c())    # 1
print(c())    # 2
print(c())    # 3
```

### Pipe Operator

The `|>` operator passes the left side as the first argument to the right side. Chain transformations left-to-right instead of nesting calls.

```crux
# Without pipes (inside-out reading)
print(square(double(5)))

# With pipes (left-to-right reading)
5 |> double |> square |> print

# Extra arguments are appended
10 |> add(5)    # equivalent to add(10, 5)
```

### Arrays

```crux
let nums = [1, 2, 3, 4, 5]
print(nums[0])          # 1
print(nums[-1])         # 5
nums[0] = 99

# Functional operations
let doubled = map(nums, fn(x) -> x * 2)
let evens = filter(nums, fn(x) -> x % 2 == 0)
let total = reduce(nums, 0, fn(a, b) -> a + b)

# Generate ranges
let digits = range(0, 10)    # [0, 1, 2, ..., 9]
```

### Hashmaps

```crux
let person = {"name": "Alice", "age": 30}
print(person["name"])       # Alice
person["role"] = "Engineer"

print(keys(person))         # [name, age, role]
print(has_key(person, "age"))  # true
```

### Control Flow

```crux
# If expressions return values
let status = if x > 0 then "positive" else "non-positive" end

# While loops
let i = 0
while i < 10 do
  i = i + 1
end

# For-in loops
for item in [1, 2, 3] do
  print(item)
end

for i in range(0, 5) do
  print("${i} squared = ${i * i}")
end
```

### Error Handling

```crux
# try/catch catches runtime errors and user-thrown errors
let safe_div = fn(a, b) ->
  try
    a / b
  catch e ->
    print("Error: ${e}")
    0
  end

safe_div(10, 0)    # prints error, returns 0

# throw raises catchable errors
throw "something went wrong"
```

### Comments

```crux
# Single-line comment

/* Multi-line block comment
   that can span lines */

/* Nested /* comments */ work too */
```

### Recursion

```crux
let fib = fn(n) ->
  if n <= 1 then n
  else fib(n - 1) + fib(n - 2) end

print(fib(10))    # 55
```

## Built-in Functions

### Core

| Function | Description |
|----------|-------------|
| `print(x)` | Print a value with newline |
| `println(a, b, ...)` | Print multiple values space-separated |
| `str(x)` | Convert to string |
| `len(x)` | Length of string, array, or hash |
| `type(x)` | Type name as string |

### Math

| Function | Description |
|----------|-------------|
| `abs(n)` | Absolute value |
| `max(a, b)` | Maximum of two numbers |
| `min(a, b)` | Minimum of two numbers |
| `floor(n)` | Round down |
| `ceil(n)` | Round up |
| `round(n)` / `round(n, digits)` | Round to nearest |
| `sqrt(n)` | Square root |
| `pow(base, exp)` | Exponentiation |
| `random()` | Random float in [0, 1) |

### Strings

| Function | Description |
|----------|-------------|
| `upper(s)` | Uppercase |
| `lower(s)` | Lowercase |
| `trim(s)` | Strip whitespace |
| `split(s, delim)` | Split into array |
| `replace(s, old, new)` | Global replace |
| `contains(s, substr)` | Substring check |
| `chars(s)` | Split into character array |
| `slice(s, start, len)` | Substring extraction |

### Arrays

| Function | Description |
|----------|-------------|
| `push(arr, val)` | Append (mutates) |
| `pop(arr)` | Remove last (mutates) |
| `first(arr)` / `last(arr)` | First/last element |
| `reverse(arr)` | Reversed copy |
| `sort(arr)` | Sorted copy |
| `concat(a, b)` | Concatenate two arrays |
| `join(arr, sep)` | Join into string |
| `range(start, stop)` | Integer sequence [start, stop) |
| `empty(arr)` | Check if empty |
| `map(arr, fn)` | Transform each element |
| `filter(arr, fn)` | Keep matching elements |
| `reduce(arr, init, fn)` | Fold to single value |
| `each(arr, fn)` | Side-effect iteration |

### Hashmaps

| Function | Description |
|----------|-------------|
| `keys(h)` | Array of keys |
| `values(h)` | Array of values |
| `has_key(h, k)` | Check key existence |
| `merge(a, b)` | Merge two hashes |

### Conversion

| Function | Description |
|----------|-------------|
| `to_int(x)` | Convert to integer |
| `to_float(x)` | Convert to float |

## Implementation

The interpreter has five components:

1. **Lexer** (`lib/crux/lexer.rb`) — Transforms source text into tokens. Handles numbers, strings with interpolation and escapes, operators, keywords, and both line and block comments.

2. **Parser** (`lib/crux/parser.rb`) — Recursive-descent parser that builds an immutable AST. Handles operator precedence through precedence climbing.

3. **AST** (`lib/crux/ast.rb`) — All nodes are `Data.define` value objects, making the tree immutable by construction. Pattern matching works naturally.

4. **Interpreter** (`lib/crux/interpreter.rb`) — Tree-walk evaluator using Ruby's pattern matching (`case/in`). Closures capture their `Environment` at definition time.

5. **Environment** (`lib/crux/environment.rb`) — Linked scope chain that enables lexical scoping. Assignment walks the chain to find the original binding, which is what makes closure mutation work.

## Running Tests

```bash
ruby -Itest test/lexer_test.rb
ruby -Itest test/parser_test.rb
ruby -Itest test/interpreter_test.rb

# Or all at once
rake test
```

## License

MIT
