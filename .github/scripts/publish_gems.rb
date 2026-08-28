# frozen_string_literal: true

require "rubygems/package"

require_relative "native_platforms"

directory = File.expand_path(ARGV.fetch(0, "pkg"))
gem_files = Dir[File.join(directory, "*.gem")]
abort "No gems found in #{directory}" if gem_files.empty?

source_gems, platform_gems = gem_files.partition do |file|
  Gem::Package.new(file).spec.platform == Gem::Platform::RUBY
end
abort "Expected exactly one source fallback gem" unless source_gems.one?

platforms = platform_gems.map { |file| Gem::Package.new(file).spec.platform.to_s }
expected_platforms = [*ENVAMELEON_NOOP_PLATFORMS, *ENVAMELEON_NATIVE_PLATFORMS]
abort "Platform-specific gems differ: #{platforms.sort}" unless platforms.sort == expected_platforms.sort

[*platform_gems.sort, source_gems.first].each do |gem_file|
  abort "Failed to publish #{gem_file}" unless system("gem", "push", gem_file)
end
