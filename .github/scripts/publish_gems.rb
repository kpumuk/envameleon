# frozen_string_literal: true

require "rubygems/package"

require_relative "native_platforms"

directory = File.expand_path(ARGV.fetch(0, "pkg"))
gem_files = Dir[File.join(directory, "*.gem")]
abort "No gems found in #{directory}" if gem_files.empty?

platform_neutral_gems, linux_gems = gem_files.partition do |file|
  Gem::Package.new(file).spec.platform == Gem::Platform::RUBY
end
abort "Expected exactly one platform-neutral gem" unless platform_neutral_gems.one?

source_gems, native_gems = linux_gems.partition do |file|
  Gem::Package.new(file).spec.platform.to_s == ENVAMELEON_SOURCE_PLATFORM
end
abort "Expected exactly one source fallback gem" unless source_gems.one?

[*native_gems.sort, source_gems.first, platform_neutral_gems.first].each do |gem_file|
  abort "Failed to publish #{gem_file}" unless system("gem", "push", gem_file)
end
