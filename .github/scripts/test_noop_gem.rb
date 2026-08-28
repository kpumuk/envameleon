# frozen_string_literal: true

require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

require_relative "verify_release_gems"

def run!(*command, env: {})
  stdout, stderr, status = Open3.capture3(env, *command)
  $stdout.write(stdout)
  $stderr.write(stderr)
  abort "Command failed (#{status.exitstatus}): #{command.join(" ")}" unless status.success?
end

expected_platform = case RbConfig::CONFIG.fetch("host_os")
when /darwin/
  "universal-darwin"
when /mingw|mswin/
  "universal-mingw"
else
  abort "No no-op gem is defined for #{RUBY_PLATFORM}"
end

path = File.expand_path(ARGV.fetch(0, "pkg"))
gem_files = if File.directory?(path)
  Dir[File.join(path, "*.gem")].select do |file|
    Gem::Package.new(file).spec.platform.to_s == expected_platform
  end
else
  [path]
end
abort "Expected exactly one #{expected_platform} gem, found #{gem_files.length}" unless gem_files.one?

gem_file = gem_files.first
ENVameleon::ReleaseGems.verify_package!(gem_file, expected_platform)

Dir.mktmpdir("envameleon-noop-gem-") do |gem_home|
  environment = {
    "CC" => File::NULL,
    "GEM_HOME" => gem_home,
    "GEM_PATH" => "",
    "MAKE" => File::NULL
  }
  run!(
    Gem.ruby, "-S", "gem", "install", "--local", "--no-document",
    "--install-dir", gem_home, gem_file,
    env: environment
  )

  installed_specification_file = Dir[File.join(gem_home, "specifications", "envameleon-*.gemspec")]
  abort "Expected one installed gemspec" unless installed_specification_file.one?

  installed_specification = Gem::Specification.load(installed_specification_file.first)
  abort "Could not load installed gemspec" unless installed_specification

  run!(
    Gem.ruby,
    "-I#{File.join(installed_specification.full_gem_path, "lib")}",
    File.expand_path("../../test/test_envameleon.rb", __dir__)
  )
end
