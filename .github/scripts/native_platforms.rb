# frozen_string_literal: true

require "rubygems"

ENVAMELEON_NATIVE_PLATFORMS = %w[
  aarch64-linux-gnu
  aarch64-linux-musl
  x86_64-linux-gnu
  x86_64-linux-musl
].freeze

ENVAMELEON_NOOP_PLATFORMS = %w[
  universal-darwin
  universal-mingw
].freeze

ENVAMELEON_SOURCE_PLATFORM = Gem::Platform::RUBY.to_s
ENVAMELEON_RUBY_API_VERSIONS = %w[3.2 3.3 3.4 4.0].freeze
ENVAMELEON_NEXT_RUBY_API_VERSION = "4.1"
ENVAMELEON_RUBY_REQUIREMENTS = ENVAMELEON_RUBY_API_VERSIONS.map { |version| "~> #{version}.0" }.freeze

ENVAMELEON_RUBY_REQUIREMENT = Gem::Requirement.new(">= #{ENVAMELEON_RUBY_API_VERSIONS.first}.0")
ENVAMELEON_NATIVE_RUBY_REQUIREMENT = Gem::Requirement.new(
  ENVAMELEON_RUBY_REQUIREMENT,
  "< #{ENVAMELEON_NEXT_RUBY_API_VERSION}.0.dev"
)
