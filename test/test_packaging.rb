# frozen_string_literal: true

require "test/unit"

require_relative "../.github/scripts/native_platforms"

class PackagingTest < Test::Unit::TestCase
  def test_release_platforms_are_distinct
    assert_equal(%w[universal-darwin universal-mingw], ENVAMELEON_NOOP_PLATFORMS)
    assert_equal("ruby", ENVAMELEON_SOURCE_PLATFORM)
    assert_empty(ENVAMELEON_NOOP_PLATFORMS & ENVAMELEON_NATIVE_PLATFORMS)
    assert_not_include(ENVAMELEON_NATIVE_PLATFORMS, ENVAMELEON_SOURCE_PLATFORM)
  end

  def test_next_ruby_api_version_is_explicit_and_includes_head
    assert_not_include(ENVAMELEON_RUBY_API_VERSIONS, ENVAMELEON_NEXT_RUBY_API_VERSION)
    assert_operator(
      Gem::Version.new(ENVAMELEON_NEXT_RUBY_API_VERSION),
      :>,
      Gem::Version.new(ENVAMELEON_RUBY_API_VERSIONS.last)
    )

    minimum = ENVAMELEON_RUBY_API_VERSIONS.first
    next_ruby = ENVAMELEON_NEXT_RUBY_API_VERSION
    assert_equal(Gem::Requirement.new(">= #{minimum}"), ENVAMELEON_NOOP_RUBY_REQUIREMENT)
    assert_equal(
      Gem::Requirement.new(">= #{minimum}", "< #{next_ruby}.0.dev"),
      ENVAMELEON_NATIVE_RUBY_REQUIREMENT
    )
    assert_equal(Gem::Requirement.new(">= #{next_ruby}.0.dev"), ENVAMELEON_SOURCE_RUBY_REQUIREMENT)

    latest_supported = Gem::Version.new("#{ENVAMELEON_RUBY_API_VERSIONS.last}.99")
    next_development = Gem::Version.new("#{next_ruby}.0dev")
    assert_true(ENVAMELEON_NATIVE_RUBY_REQUIREMENT.satisfied_by?(latest_supported))
    assert_false(ENVAMELEON_NATIVE_RUBY_REQUIREMENT.satisfied_by?(next_development))
    assert_true(ENVAMELEON_SOURCE_RUBY_REQUIREMENT.satisfied_by?(next_development))
  end
end
