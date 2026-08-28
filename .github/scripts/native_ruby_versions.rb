# frozen_string_literal: true

require "json"

require_relative "native_platforms"

versions = JSON.generate(ENVAMELEON_RUBY_API_VERSIONS)
puts versions

if (github_output = ENV["GITHUB_OUTPUT"])
  File.open(github_output, "a") { |file| file.puts "versions=#{versions}" }
end
