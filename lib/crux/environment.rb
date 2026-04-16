# frozen_string_literal: true

require "set"

module Crux
  # A lexical scope that chains to an optional parent.
  class Environment
    attr_reader :parent

    # parent - An optional Environment representing the enclosing scope.
    def initialize(parent: nil)
      @bindings = {}
      @frozen = Set.new
      @parent = parent
    end

    # Define a new variable in this scope.
    def define(name, value)
      @bindings[name] = value
    end

    # Define a constant (immutable binding) in this scope.
    def define_const(name, value)
      @bindings[name] = value
      @frozen.add(name)
    end

    # Look up a variable by name, walking the scope chain.
    def fetch(name)
      return @bindings[name] if @bindings.key?(name)
      return @parent.fetch(name) if @parent

      raise Crux::RuntimeError, "Undefined variable '#{name}'"
    end

    # Assign a new value to an existing variable.
    def assign(name, value)
      if @bindings.key?(name)
        raise Crux::RuntimeError, "Cannot reassign constant '#{name}'" if @frozen.include?(name)
        @bindings[name] = value
      elsif @parent
        @parent.assign(name, value)
      else
        raise Crux::RuntimeError, "Undefined variable '#{name}' — use 'let' to declare it first"
      end
    end
  end
end
