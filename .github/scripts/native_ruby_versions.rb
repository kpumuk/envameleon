# frozen_string_literal: true

require "json"

require_relative "native_platforms"

versions = JSON.generate(ENVAMELEON_RUBY_API_VERSIONS)
puts versions

if (github_output = ENV["GITHUB_OUTPUT"])
  File.open(github_output, "a") do |file|
    file.puts "versions=#{versions}"
    file.puts "latest=#{ENVAMELEON_RUBY_API_VERSIONS.last}"
    file.puts "next=#{ENVAMELEON_NEXT_RUBY_API_VERSION}"
  end
end
