# frozen_string_literal: true

require "rake/clean"
require "rake/extensiontask"
require "rake_compiler_dock"
require "bundler"
require "fileutils"

require_relative ".github/scripts/native_platforms"

specification = Gem::Specification.load("envameleon.gemspec")
abort "Could not load envameleon.gemspec" unless specification

source_specification = specification.dup
source_specification.platform = Gem::Platform.new(ENVAMELEON_SOURCE_PLATFORM)
source_specification.required_ruby_version = ENVAMELEON_SOURCE_RUBY_REQUIREMENT
source_specification.files += Dir["ext/**/*.{c,rb}"]
source_specification.files.delete("lib/envameleon/noop.rb")
source_specification.extensions = ["ext/envameleon/extconf.rb"]

bundler_version = Bundler::VERSION

RakeCompilerDock.set_ruby_cc_version(*ENVAMELEON_RUBY_REQUIREMENTS)

Gem::PackageTask.new(specification).define
Gem::PackageTask.new(source_specification).define

Rake::ExtensionTask.new("envameleon/envameleon", specification) do |extension|
  extension.ext_dir = "ext/envameleon"
  extension.cross_compile = true
  extension.cross_platform = ENVAMELEON_NATIVE_PLATFORMS
  extension.cross_compiling do |native_specification|
    native_specification.required_ruby_version = ENVAMELEON_NATIVE_RUBY_REQUIREMENT
    native_specification.files.reject! do |path|
      path.start_with?("assets/", "ext/") || path == "lib/envameleon/noop.rb"
    end
  end
end

desc "Compile the extension and run the tests"
test_prerequisites = RUBY_PLATFORM.include?("linux") ? [:compile] : []
task test: test_prerequisites do
  ruby "-Ilib", "test/test_envameleon.rb"
  ruby "test/test_packaging.rb"
end

namespace :gem do
  ENVAMELEON_NATIVE_PLATFORMS.each do |platform|
    desc "Build the native gem for #{platform}"
    task platform do
      gem_file = "pkg/#{specification.full_name}-#{Gem::Platform.new(platform)}.gem"
      FileUtils.rm_f(gem_file)
      FileUtils.rm_rf(gem_file.delete_suffix(".gem"))

      command = "gem install --no-document bundler --version #{bundler_version} " \
        "--clear-sources --source https://rubygems.org && " \
        "bundle _#{bundler_version}_ config set --local deployment true && " \
        "bundle _#{bundler_version}_ install --local && " \
        "bundle _#{bundler_version}_ exec rake clean native:#{platform} #{gem_file}"

      RakeCompilerDock.sh(
        command,
        platform: platform,
        verbose: true
      )
    end
  end
end

task default: :test

CLEAN.include(
  "lib/envameleon/envameleon.bundle",
  "lib/envameleon/envameleon.dll",
  "lib/envameleon/envameleon.dylib",
  "lib/envameleon/envameleon.so",
  "tmp"
)
CLOBBER.include("pkg")
