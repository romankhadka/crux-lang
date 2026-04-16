# frozen_string_literal: true

module Crux
  # A lexical scope that chains to an optional parent.
  #
  # Each Environment holds a hash of variable bindings and a reference
  # to an enclosing scope. Variable lookup walks the chain outward,
  # implementing lexical (static) scoping.
  #
  # This is the backbone of closures: when a function is created, it
  # captures the Environment it was defined in. When called, a new
  # child Environment extends that captured scope.
  class Environment
    attr_reader :parent

    # parent - An optional Environment representing the enclosing scope.
    def initialize(parent: nil)
      @bindings = {}
      @parent = parent
    end

    # Define a new variable in this scope.
    #
    # name  - A String variable name.
    # value - The value to bind.
    #
    # Returns the value.
    def define(name, value)
      @bindings[name] = value
    end

    # Look up a variable by name, walking the scope chain.
    #
    # name - A String variable name.
    #
    # Returns the bound value.
    # Raises Crux::RuntimeError if the variable is not defined.
    def fetch(name)
      return @bindings[name] if @bindings.key?(name)
      return @parent.fetch(name) if @parent

      raise Crux::RuntimeError, "Undefined variable '#{name}'"
    end

    # Assign a new value to an existing variable.
    #
    # Assignment walks the scope chain to find where the variable
    # was originally defined, then updates it there. This is what
    # makes closures able to mutate captured variables.
    #
    # name  - A String variable name.
    # value - The new value.
    #
    # Returns the value.
    # Raises Crux::RuntimeError if the variable is not defined.
    def assign(name, value)
      if @bindings.key?(name)
        @bindings[name] = value
      elsif @parent
        @parent.assign(name, value)
      else
        raise Crux::RuntimeError, "Undefined variable '#{name}' — use 'let' to declare it first"
      end
    end
  end
end
