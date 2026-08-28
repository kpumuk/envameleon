# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "envameleon"
  spec.version = "0.2.0"
  spec.authors = ["Dmytro Shteflyuk"]
  spec.summary = "Leave no ENVidence."
  spec.description = "Scrub, mask, or drop Linux's /proc/self/environ view without changing Ruby's ENV."
  spec.license = "MIT"
  spec.homepage = "https://github.com/kpumuk/envameleon"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["README.md", "LICENSE.txt", "lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata = {
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => spec.homepage
  }

  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rake-compiler", "~> 1.3.1"
  spec.add_development_dependency "rake-compiler-dock", "~> 1.12"
  spec.add_development_dependency "test-unit", "~> 3.7"
end
