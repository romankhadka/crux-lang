# Crux

A tiny programming language with closures and pipes, implemented as a tree-walk interpreter in ~500 lines of Ruby.

Crux is an expression-oriented language with first-class functions, lexical closures, and a pipe operator (`|>`) for clean functional composition.

## Quick Start

```bash
# Run a program
ruby bin/crux examples/fibonacci.crux

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

### Functions

Functions are first-class values. They close over their defining scope.

```crux
let greet = fn(name) -> "Hello, " + name
print(greet("world"))

# Multi-expression bodies use do...end
let max3 = fn(a, b, c) -> do
  let m = if a > b then a else b end
  if m > c then m else c end
end
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

### Control Flow

```crux
# If expressions return values
let status = if x > 0 then "positive" else "non-positive" end

# While loops
let sum = 0
let i = 1
while i <= 100 do
  sum = sum + i
  i = i + 1
end
```

### Recursion

```crux
let fib = fn(n) ->
  if n <= 1 then n
  else fib(n - 1) + fib(n - 2) end

print(fib(10))    # 55
```

## Built-in Functions

| Function | Description |
|----------|-------------|
| `print(x)` | Print a value with newline |
| `println(a, b, ...)` | Print multiple values space-separated |
| `str(x)` | Convert to string |
| `len(s)` | String length |
| `type(x)` | Type name as string |
| `abs(n)` | Absolute value |
| `max(a, b)` | Maximum of two numbers |
| `min(a, b)` | Minimum of two numbers |
| `to_int(x)` | Convert to integer |
| `to_float(x)` | Convert to float |

## Implementation

The interpreter has four stages:

1. **Lexer** (`lib/crux/lexer.rb`) — Transforms source text into tokens. Handles numbers, strings with escapes, operators, keywords, and comments.

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
