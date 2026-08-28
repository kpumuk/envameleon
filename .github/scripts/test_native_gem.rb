# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

def run!(*command, env: {})
  stdout, stderr, status = Open3.capture3(env, *command)
  $stdout.write(stdout)
  $stderr.write(stderr)
  abort "Command failed (#{status.exitstatus}): #{command.join(" ")}" unless status.success?
end

gem_directory = File.expand_path(ARGV.fetch(0, "pkg"))
gem_files = File.directory?(gem_directory) ? Dir[File.join(gem_directory, "*.gem")] : [gem_directory]
abort "Expected exactly one gem, found #{gem_files.length}" unless gem_files.one?

gem_file = gem_files.first
specification = Gem::Package.new(gem_file).spec
expected_platform = ENV.fetch("EXPECTED_PLATFORM")
abort "Expected #{expected_platform}, got #{specification.platform}" unless specification.platform.to_s == expected_platform
abort "Native gem unexpectedly has an extension build hook" unless specification.extensions.empty?
abort "Native gem does not support Ruby #{RUBY_VERSION}" unless specification.required_ruby_version.satisfied_by?(Gem::Version.new(RUBY_VERSION))

ruby_api_version = RUBY_VERSION[/\A\d+\.\d+/]
extension = "lib/envameleon/#{ruby_api_version}/envameleon.#{RbConfig::CONFIG.fetch("DLEXT")}"
abort "Native gem is missing #{extension}" unless specification.files.include?(extension)

Dir.mktmpdir("envameleon-native-gem-") do |gem_home|
  install_environment = {
    "CC" => File::NULL,
    "GEM_HOME" => gem_home,
    "GEM_PATH" => "",
    "MAKE" => File::NULL
  }
  run!(
    Gem.ruby, "-S", "gem", "install", "--local", "--no-document",
    "--install-dir", gem_home, gem_file,
    env: install_environment
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
