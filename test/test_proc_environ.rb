# frozen_string_literal: true

require "test/unit"

class ProcEnvironTest < Test::Unit::TestCase
  def test_require
    environment = ENV.to_h
    proc_environment = nil

    if RUBY_PLATFORM.include?("linux")
      proc_environment = File.binread("/proc/self/environ")
      assert_not_empty(proc_environment)
    end

    require "proc_environ"

    assert_equal(environment, ENV.to_h)
    ENV["PROC_ENVIRON_MUTATION_TEST"] = "still works"
    assert_equal("still works", ENV["PROC_ENVIRON_MUTATION_TEST"])

    if proc_environment
      assert_equal("\0".b * proc_environment.bytesize, File.binread("/proc/self/environ"))
    end
  end
end
