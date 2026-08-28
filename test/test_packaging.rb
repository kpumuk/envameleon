# frozen_string_literal: true

require "test/unit"

require_relative "../.github/scripts/native_platforms"

class PackagingTest < Test::Unit::TestCase
  def test_next_ruby_api_version_is_explicit_and_includes_head
    assert_equal("4.1", ENVAMELEON_NEXT_RUBY_API_VERSION)
    assert_not_include(ENVAMELEON_RUBY_API_VERSIONS, ENVAMELEON_NEXT_RUBY_API_VERSION)
    assert_operator(
      Gem::Version.new(ENVAMELEON_NEXT_RUBY_API_VERSION),
      :>,
      Gem::Version.new(ENVAMELEON_RUBY_API_VERSIONS.last)
    )
    assert_equal(">= 3.2, < 4.1.0.dev", ENVAMELEON_NATIVE_RUBY_REQUIREMENT.to_s)
    assert_equal(">= 4.1.0.dev", ENVAMELEON_SOURCE_RUBY_REQUIREMENT.to_s)
    assert_true(ENVAMELEON_NATIVE_RUBY_REQUIREMENT.satisfied_by?(Gem::Version.new("4.0.99")))
    assert_false(ENVAMELEON_NATIVE_RUBY_REQUIREMENT.satisfied_by?(Gem::Version.new("4.1.0dev")))
    assert_true(ENVAMELEON_SOURCE_RUBY_REQUIREMENT.satisfied_by?(Gem::Version.new("4.1.0dev")))
  end
end
