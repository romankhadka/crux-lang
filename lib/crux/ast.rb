# frozen_string_literal: true

module Crux
  # Abstract Syntax Tree nodes.
  #
  # Every node is a frozen Data.define value object, making the AST
  # immutable by construction. Pattern matching with `in` works
  # naturally on all node types.
  module AST
    # -- Literals ----------------------------------------------------------

    # A numeric literal (integer or float).
    NumberLit = Data.define(:value)

    # A string literal.
    StringLit = Data.define(:value)

    # A boolean literal (true or false).
    BoolLit = Data.define(:value)

    # A string interpolation: "Hello, ${expr}!".
    #
    # parts - An Array of AST nodes (StringLit for literal parts, expressions for interpolated parts).
    Interpolation = Data.define(:parts)

    # The nil literal.
    NilLit = Data.define

    # An array literal: [1, 2, 3].
    #
    # elements - An Array of AST nodes.
    ArrayLit = Data.define(:elements)

    # A hash literal: {key: value, ...}.
    #
    # pairs - An Array of [AST node, AST node] pairs (key, value).
    HashLit = Data.define(:pairs)

    # -- Expressions -------------------------------------------------------

    # A variable reference.
    Identifier = Data.define(:name)

    # A unary operation (e.g., -x, not x).
    #
    # operator - A Symbol (:minus or :not).
    # operand  - An AST node.
    UnaryOp = Data.define(:operator, :operand)

    # A binary operation (e.g., x + y, x == y).
    #
    # operator - A Symbol (:plus, :minus, :star, :slash, :percent,
    #            :equal_equal, :bang_equal, :less, :greater,
    #            :less_equal, :greater_equal, :and, :or).
    # left     - An AST node.
    # right    - An AST node.
    BinaryOp = Data.define(:operator, :left, :right)

    # A function call.
    #
    # callee    - An AST node that evaluates to a callable.
    # arguments - An Array of AST nodes.
    Call = Data.define(:callee, :arguments)

    # An index access: expr[expr].
    #
    # object - An AST node that evaluates to an indexable value.
    # index  - An AST node that evaluates to the index.
    IndexAccess = Data.define(:object, :index)

    # An index assignment: expr[expr] = expr.
    #
    # object - An AST node that evaluates to an indexable value.
    # index  - An AST node that evaluates to the index.
    # value  - An AST node for the new value.
    IndexAssign = Data.define(:object, :index, :value)

    # A pipe expression: value |> function.
    #
    # value     - An AST node (the left side, piped as first argument).
    # function  - An AST node that evaluates to a callable.
    # arguments - An Array of additional AST nodes.
    Pipe = Data.define(:value, :function, :arguments)

    # -- Definitions -------------------------------------------------------

    # A function literal: fn(params) -> body.
    #
    # params - An Array of String parameter names.
    # body   - An AST node (the function body).
    Function = Data.define(:params, :body)

    # A let binding: let name = value.
    #
    # name  - A String variable name.
    # value - An AST node.
    LetBinding = Data.define(:name, :value)

    # A variable reassignment: name = value.
    #
    # name  - A String variable name.
    # value - An AST node.
    Assignment = Data.define(:name, :value)

    # -- Control flow ------------------------------------------------------

    # An if expression: if cond then a else b end.
    #
    # condition   - An AST node.
    # then_branch - An AST node.
    # else_branch - An AST node or nil.
    If = Data.define(:condition, :then_branch, :else_branch)

    # A while loop: while cond do body end.
    #
    # condition - An AST node.
    # body      - An AST node.
    While = Data.define(:condition, :body)

    # A for-in loop: for name in iterable do body end.
    #
    # name     - A String variable name for each element.
    # iterable - An AST node that evaluates to an array.
    # body     - An AST node.
    ForIn = Data.define(:name, :iterable, :body)

    # A block of statements: do stmt1; stmt2; expr end.
    # The last expression is the block's value.
    #
    # statements - An Array of AST nodes.
    Block = Data.define(:statements)

    # -- Program -----------------------------------------------------------

    # The top-level program node.
    #
    # statements - An Array of AST nodes.
    Program = Data.define(:statements)
  end
end
