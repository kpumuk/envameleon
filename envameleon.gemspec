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
  spec.files = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "ext/**/*.{c,rb}"]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/envameleon/extconf.rb"]
  spec.metadata = {
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => spec.homepage
  }
end
