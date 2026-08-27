# frozen_string_literal: true

require "test/unit"

class ProcEnvironTest < Test::Unit::TestCase
  def test_require
    environment = ENV.to_h

    if RUBY_PLATFORM.include?("linux")
      assert_not_empty(File.binread("/proc/self/environ"))
    end

    require "proc_environ"

    assert_equal(environment, ENV.to_h)
    assert_empty(File.binread("/proc/self/environ")) if RUBY_PLATFORM.include?("linux")
  end
end
