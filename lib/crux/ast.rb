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

    # The nil literal.
    NilLit = Data.define

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
