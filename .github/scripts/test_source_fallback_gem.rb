# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"

require_relative "verify_release_gems"

def run!(*command, env: {})
  stdout, stderr, status = Open3.capture3(env, *command)
  $stdout.write(stdout)
  $stderr.write(stderr)
  abort "Command failed (#{status.exitstatus}): #{command.join(" ")}" unless status.success?
end

path = File.expand_path(ARGV.fetch(0, "pkg"))
gem_files = File.directory?(path) ? Dir[File.join(path, "*-#{ENVAMELEON_SOURCE_PLATFORM}.gem")] : [path]
abort "Expected exactly one source fallback gem, found #{gem_files.length}" unless gem_files.one?

gem_file = gem_files.first
specification = Gem::Package.new(gem_file).spec
expected_platform = ENVAMELEON_SOURCE_PLATFORM
abort "Expected #{expected_platform}, got #{specification.platform}" unless specification.platform.to_s == expected_platform

ENVameleon::ReleaseGems.verify_package!(gem_file, expected_platform)

Dir.mktmpdir("envameleon-source-fallback-") do |gem_home|
  environment = {
    "GEM_HOME" => gem_home,
    "GEM_PATH" => gem_home
  }
  run!(
    Gem.ruby, "-S", "gem", "install", "--local", "--no-document",
    "--install-dir", gem_home, gem_file,
    env: environment
  )

  extension = Dir[File.join(gem_home, "extensions", "**", "envameleon.#{RbConfig::CONFIG.fetch("DLEXT")}")]
  abort "Expected one compiled extension, found #{extension.length}" unless extension.one?

  installed_specification_file = Dir[File.join(gem_home, "specifications", "envameleon-*.gemspec")]
  abort "Expected one installed gemspec" unless installed_specification_file.one?

  installed_specification = Gem::Specification.load(installed_specification_file.first)
  abort "Could not load installed gemspec" unless installed_specification

  run!(
    Gem.ruby,
    "-I#{File.join(installed_specification.full_gem_path, "lib")}",
    "-I#{File.dirname(File.dirname(extension.first))}",
    File.expand_path("../../test/test_envameleon.rb", __dir__),
  )
end
