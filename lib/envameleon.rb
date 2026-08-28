# frozen_string_literal: true

require "rbconfig"

ruby_api_version = RUBY_VERSION[/\A\d+\.\d+/]
native_extension = File.expand_path(
  "envameleon/#{ruby_api_version}/envameleon.#{RbConfig::CONFIG.fetch("DLEXT")}",
  __dir__
)
development_extension = File.expand_path(
  "envameleon/envameleon.#{RbConfig::CONFIG.fetch("DLEXT")}",
  __dir__
)

if RbConfig::CONFIG.fetch("host_os").include?("linux")
  extension = [native_extension, development_extension].find { |path| File.file?(path) }
  if extension
    require extension
  else
    begin
      require "envameleon/envameleon"
    rescue LoadError => error
      raise unless error.path == "envameleon/envameleon"

      raise LoadError, "ENVameleon has no native extension for Ruby #{ruby_api_version} on #{RUBY_PLATFORM}"
    end
  end
else
  require_relative "envameleon/noop"
end
