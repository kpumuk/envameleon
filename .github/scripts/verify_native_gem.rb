# frozen_string_literal: true

require_relative "verify_release_gems"

path = File.expand_path(ARGV.fetch(0, "pkg"))
expected_platform = ARGV.fetch(1)
gem_files = File.directory?(path) ? Dir[File.join(path, "*.gem")] : [path]
abort "Expected exactly one gem, found #{gem_files.length}" unless gem_files.one?

gem_file = gem_files.first
specification = Gem::Package.new(gem_file).spec
abort "Expected #{expected_platform}, got #{specification.platform}" unless specification.platform.to_s == expected_platform

ENVameleon::ReleaseGems.verify_package!(gem_file, expected_platform)
puts ENVameleon::ReleaseGems.checksums(gem_files)
