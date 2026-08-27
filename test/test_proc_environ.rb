# frozen_string_literal: true

require "test/unit"

class ProcEnvironTest < Test::Unit::TestCase
  def test_proc_data
    environment = ENV.to_h
    proc_environment = nil

    if RUBY_PLATFORM.include?("linux")
      proc_environment = File.binread("/proc/self/environ")
      assert_not_empty(proc_environment)
    end

    require "proc_environ"

    assert_respond_to(ENV, :scrub_proc_data)
    assert_respond_to(ENV, :mask_proc_data)
    assert_equal(environment, ENV.to_h)

    if proc_environment
      assert_equal(proc_environment, File.binread("/proc/self/environ"))
      assert_nil(ENV.mask_proc_data)
      assert_equal(mask(proc_environment), File.binread("/proc/self/environ"))
      assert_equal(environment, ENV.to_h)

      assert_nil(ENV.scrub_proc_data)
      assert_equal("\0".b * proc_environment.bytesize, File.binread("/proc/self/environ"))
      assert_equal(environment, ENV.to_h)
    else
      assert_nil(ENV.mask_proc_data)
      assert_nil(ENV.scrub_proc_data)
      assert_equal(environment, ENV.to_h)
    end

    ENV["PROC_ENVIRON_MUTATION_TEST"] = "still works"
    assert_equal("still works", ENV["PROC_ENVIRON_MUTATION_TEST"])
  ensure
    ENV.delete("PROC_ENVIRON_MUTATION_TEST")
  end

  private

  def mask(contents)
    contents.split("\0", -1).map do |entry|
      name, separator, value = entry.partition("=")
      next entry if separator.empty? || value.bytesize < 3

      "#{name}=#{value.byteslice(0)}#{"*".b * (value.bytesize - 2)}#{value.byteslice(-1)}"
    end
      .join("\0")
  end
end
