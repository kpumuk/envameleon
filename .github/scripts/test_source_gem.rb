# frozen_string_literal: true

require "open3"
require "rubygems/package"
require "tmpdir"

def run!(*command, env: {})
  stdout, stderr, status = Open3.capture3(env, *command)
  $stdout.write(stdout)
  $stderr.write(stderr)
  abort "Command failed (#{status.exitstatus}): #{command.join(" ")}" unless status.success?
end

gem_directory = File.expand_path(ARGV.fetch(0, "."))
gem_files = File.directory?(gem_directory) ? Dir[File.join(gem_directory, "envameleon-*.gem")] : [gem_directory]
abort "Expected exactly one gem, found #{gem_files.length}" unless gem_files.one?

gem_file = gem_files.first
specification = Gem::Package.new(gem_file).spec
abort "Expected a platform-neutral gem, got #{specification.platform}" unless specification.platform == Gem::Platform::RUBY
abort "Platform-neutral gem has an extension build hook" unless specification.extensions.empty?

Dir.mktmpdir("envameleon-source-gem-") do |gem_home|
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

  load_path = "-I#{File.join(installed_specification.full_gem_path, "lib")}"
  if RUBY_PLATFORM.include?("linux")
    run!(
      Gem.ruby,
      load_path,
      "-e",
      <<~'RUBY'
        begin
          require "envameleon"
        rescue LoadError => error
          expected = "ENVameleon has no native extension"
          abort "Unexpected LoadError: #{error.message}" unless error.message.include?(expected)
        else
          abort "Platform-neutral gem loaded without a native Linux extension"
        end
      RUBY
    )
  else
    run!(
      Gem.ruby,
      load_path,
      File.expand_path("../../test/test_envameleon.rb", __dir__)
    )
  end
end
