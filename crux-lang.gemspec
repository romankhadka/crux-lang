# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "crux-lang"
  spec.version = "0.1.0"
  spec.authors = ["Roman Khadka"]
  spec.summary = "A tiny programming language with closures and pipes"
  spec.description = <<~DESC
    Crux is a small, expressive programming language implemented as a
    tree-walk interpreter in Ruby. It features first-class functions,
    lexical closures, a pipe operator for functional composition, and
    a clean syntax inspired by ML and Ruby.
  DESC
  spec.homepage = "https://github.com/romankhadka/crux-lang"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "examples/*.crux", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["crux"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
end
