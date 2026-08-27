# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "proc-environ"
  spec.version = "0.1.0"
  spec.authors = ["Dmytro Shteflyuk"]
  spec.summary = "Hide the process environment from /proc/self/environ"
  spec.description = "Scrub, mask, or drop Linux's /proc/self/environ view without changing Ruby's ENV."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "ext/**/*.{c,rb}", "test/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/proc_environ/extconf.rb"]
end
