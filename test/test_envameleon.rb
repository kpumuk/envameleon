# frozen_string_literal: true

require "test/unit"

class ENVameleonTest < Test::Unit::TestCase
  INITIAL_ENVIRONMENT = ENV.to_h
  INITIAL_PROC_DATA = if RUBY_PLATFORM.include?("linux")
    File.binread("/proc/self/environ")
  end

  require "envameleon"

  def setup
    @environment = INITIAL_ENVIRONMENT
    @proc_data = INITIAL_PROC_DATA

    assert_not_empty(@proc_data) if @proc_data
  end

  def test_require
    require "envameleon"

    assert_respond_to(ENV, :scrub_proc_data)
    assert_respond_to(ENV, :mask_proc_data)
    assert_respond_to(ENV, :drop_proc_data)
    assert_equal(@environment, ENV.to_h)
    assert_equal(@proc_data, File.binread("/proc/self/environ")) if @proc_data
  end

  def test_methods_are_no_ops_without_linux
    omit("Linux behavior is covered by the fork tests") if RUBY_PLATFORM.include?("linux")

    assert_nil(ENV.mask_proc_data)
    assert_nil(ENV.scrub_proc_data)
    assert_nil(ENV.drop_proc_data)
    assert_equal(@environment, ENV.to_h)
  end

  def test_mask_proc_data_survives_fork
    proc_data = fork_after(:mask_proc_data)

    assert_equal(mask(@proc_data), proc_data) if proc_data
  end

  def test_scrub_proc_data_survives_fork
    proc_data = fork_after(:scrub_proc_data)

    assert_equal("\0".b * @proc_data.bytesize, proc_data) if proc_data
  end

  def test_drop_proc_data_survives_fork
    proc_data = fork_after(:drop_proc_data, privileged: true)

    assert_empty(proc_data) if proc_data
  end

  def test_mask_proc_data_with_newline_in_process_name
    omit("Linux behavior only") unless @proc_data

    proc_data = fork_after(:mask_proc_data, process_name: "bad\nname")

    assert_equal(mask(@proc_data), proc_data)
  end

  def test_scrub_proc_data_with_newline_in_process_name
    omit("Linux behavior only") unless @proc_data

    proc_data = fork_after(:scrub_proc_data, process_name: "bad\nname")

    assert_equal("\0".b * @proc_data.bytesize, proc_data)
  end

  def test_drop_proc_data_with_newline_in_process_name
    omit("Linux behavior only") unless @proc_data

    proc_data = fork_after(:drop_proc_data, privileged: true, process_name: "bad\nname")

    assert_empty(proc_data)
  end

  private

  def fork_after(method, privileged: false, process_name: nil)
    omit("fork is not supported") unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    worker = fork do
      reader.close
      begin
        File.binwrite("/proc/self/comm", process_name) if process_name
        result = ENV.public_send(method)
        child = fork do
          proc_data = File.binread("/proc/self/environ") if @proc_data
          Marshal.dump([:ok, result, ENV.to_h, proc_data], writer)
          writer.close
          exit! 0
        end
        writer.close
        _, status = Process.wait2(child)
        exit! status.exitstatus
      rescue StandardError => error
        Marshal.dump([:error, error.class.name, error.message], writer)
        writer.close
        exit! 1
      end
    end
    writer.close
    payload = Marshal.load(reader)
    reader.close
    _, status = Process.wait2(worker)

    if payload.first == :error
      omit("CAP_SYS_RESOURCE is required") if privileged && payload[1] == "Errno::EPERM"
      flunk("#{method} failed with #{payload[1]}: #{payload[2]}")
    end

    assert_predicate(status, :success?)
    assert_nil(payload[1])
    assert_equal(@environment, payload[2])
    payload[3]
  end

  def mask(contents)
    contents.split("\0", -1).map do |entry|
      name, separator, value = entry.partition("=")
      next entry if separator.empty? || value.bytesize < 3

      "#{name}=#{value.byteslice(0)}#{"*".b * (value.bytesize - 2)}#{value.byteslice(-1)}"
    end
      .join("\0")
  end
end
