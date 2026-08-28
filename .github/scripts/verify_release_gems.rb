# frozen_string_literal: true

require "digest"
require "open3"
require "rubygems/package"
require "tmpdir"

require_relative "native_platforms"

module ENVameleon
  module ReleaseGems
    module_function

    ELF_MACHINES = {
      "aarch64" => /\bAArch64\b/,
      "x86_64" => /\bX86-64\b/
    }.freeze

    def verify!(directory)
      files = Dir[File.join(directory, "*.gem")].sort
      abort "No gems found in #{directory}" if files.empty?

      packages = files.to_h { |file| [Gem::Package.new(file).spec.platform.to_s, file] }
      expected_platforms = [ENVAMELEON_SOURCE_PLATFORM, *ENVAMELEON_NOOP_PLATFORMS, *ENVAMELEON_NATIVE_PLATFORMS]
      abort "Duplicate gem platforms found" unless packages.length == files.length
      abort "Expected #{expected_platforms.sort}, got #{packages.keys.sort}" unless packages.keys.sort == expected_platforms.sort

      versions = packages.values.map { |file| Gem::Package.new(file).spec.version }.uniq
      abort "Gem versions differ: #{versions.join(", ")}" unless versions.one?

      packages.each do |platform, file|
        verify_package!(file, platform)
      end

      files
    end

    def checksums(files)
      files.map { |file| "#{Digest::SHA256.file(file).hexdigest}  #{File.basename(file)}" }.join("\n") << "\n"
    end

    def verify_package!(file, platform)
      package = Gem::Package.new(file)
      specification = package.spec
      abort "Unexpected gem name in #{file}" unless specification.name == "envameleon"
      abort "Unexpected filename for #{file}" unless File.basename(file) == specification.file_name

      case platform
      when ENVAMELEON_SOURCE_PLATFORM
        verify_source_specification!(specification)
      when *ENVAMELEON_NOOP_PLATFORMS
        verify_noop_specification!(specification, platform)
      else
        verify_native_specification!(specification, platform)
        verify_binaries!(package, platform)
      end
    end

    def verify_noop_specification!(specification, platform)
      abort "No-op #{platform} gem has an extension build hook" unless specification.extensions.empty?
      abort "No-op #{platform} gem contains build sources" if specification.files.any? { |path| path.start_with?("ext/") }
      abort "No-op #{platform} gem contains repository assets" if specification.files.any? { |path| path.start_with?("assets/") }
      abort "No-op #{platform} gem is missing its implementation" unless specification.files.include?("lib/envameleon/noop.rb")
      abort "No-op #{platform} gem contains native binaries" if specification.files.any? { |path| path.match?(%r{\Alib/envameleon/\d+\.\d+/}) }
      unless specification.required_ruby_version == ENVAMELEON_NOOP_RUBY_REQUIREMENT
        abort "No-op #{platform} Ruby requirement differs: #{specification.required_ruby_version}"
      end
    end

    def verify_source_specification!(specification)
      expected_extensions = ["ext/envameleon/extconf.rb"]
      abort "Source fallback gem extension hooks differ" unless specification.extensions == expected_extensions

      expected_sources = ["ext/envameleon/envameleon.c", "ext/envameleon/extconf.rb"]
      actual_sources = specification.files.grep(%r{\Aext/})
      abort "Source fallback gem build sources differ: #{actual_sources}" unless actual_sources.sort == expected_sources
      abort "Source fallback gem contains repository assets" if specification.files.any? { |path| path.start_with?("assets/") }
      abort "Source fallback gem contains the non-Linux no-op" if specification.files.include?("lib/envameleon/noop.rb")
      abort "Source fallback gem contains native binaries" if specification.files.any? { |path| path.match?(%r{\Alib/envameleon/\d+\.\d+/}) }
      unless specification.required_ruby_version == ENVAMELEON_SOURCE_RUBY_REQUIREMENT
        abort "Source fallback Ruby requirement differs: #{specification.required_ruby_version}"
      end
    end

    def verify_native_specification!(specification, platform)
      abort "Native #{platform} gem has an extension build hook" unless specification.extensions.empty?
      abort "Native #{platform} gem contains build sources" if specification.files.any? { |path| path.start_with?("ext/") }
      abort "Native #{platform} gem contains non-runtime assets" if specification.files.any? { |path| path.start_with?("assets/") }
      abort "Native #{platform} gem contains the non-Linux no-op" if specification.files.include?("lib/envameleon/noop.rb")
      unless specification.required_ruby_version == ENVAMELEON_NATIVE_RUBY_REQUIREMENT
        abort "Native #{platform} Ruby requirement differs: #{specification.required_ruby_version}"
      end

      extension = platform.include?("darwin") ? "bundle" : "so"
      expected_binaries = ENVAMELEON_RUBY_API_VERSIONS.map do |ruby_version|
        "lib/envameleon/#{ruby_version}/envameleon.#{extension}"
      end
      actual_binaries = specification.files.grep(%r{\Alib/envameleon/\d+\.\d+/})
      abort "Native #{platform} binaries differ: #{actual_binaries}" unless actual_binaries.sort == expected_binaries.sort
    end

    def verify_binaries!(package, platform)
      Dir.mktmpdir("envameleon-verify-") do |directory|
        package.extract_files(directory)
        extension = platform.include?("darwin") ? "bundle" : "so"
        Dir[File.join(directory, "lib", "envameleon", "*", "envameleon.#{extension}")].each do |binary|
          verify_binary!(binary, platform)
        end
      end
    end

    def verify_binary!(binary, platform)
      header = readelf!(binary, "-h")
      abort "Expected an ELF64 binary: #{binary}" unless header.match?(/^\s*Class:\s+ELF64\s*$/)
      unless header.match?(/^\s*Data:\s+2's complement, little endian\s*$/)
        abort "Expected a little-endian ELF binary: #{binary}"
      end

      architecture = platform.partition("-").first
      expected_machine = ELF_MACHINES.fetch(architecture)
      machine = header.lines.find { |line| line.match?(/^\s*Machine:/) }
      unless machine&.match?(expected_machine)
        abort "Wrong architecture in #{binary}: #{machine&.strip || "missing Machine header"}"
      end

      verify_elf_hardening!(binary)
    end

    def verify_elf_hardening!(binary)
      program_headers = readelf!(binary, "-W", "-l")
      stack = program_headers.lines.find { |line| line.match?(/^\s*GNU_STACK\s/) }
      abort "ELF binary has no GNU_STACK header: #{binary}" unless stack
      stack_flags = stack.split[-2]
      abort "Could not read GNU_STACK flags: #{binary}" unless stack_flags&.match?(/\A[RWE]+\z/)
      abort "ELF binary has an executable stack: #{binary}" if stack_flags.include?("E")
      abort "ELF binary has no GNU_RELRO segment: #{binary}" unless program_headers.match?(/^\s*GNU_RELRO\s/)

      dynamic_section = readelf!(binary, "-W", "-d")
      immediate_binding = dynamic_section.lines.any? do |line|
        line.match?(/\(BIND_NOW\)/) ||
          line.match?(/\(FLAGS\).*\bBIND_NOW\b/) ||
          line.match?(/\(FLAGS_1\).*\bNOW\b/)
      end
      abort "ELF binary does not use immediate binding: #{binary}" unless immediate_binding
    end

    def readelf!(binary, *arguments)
      environment = { "LC_ALL" => "C" }
      stdout, stderr, status = Open3.capture3(environment, "readelf", *arguments, "--", binary)
      return stdout if status.success?

      abort "readelf failed for #{binary}: #{stderr.strip}"
    rescue Errno::ENOENT
      abort "readelf is required to verify native gems; install binutils"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  directory = File.expand_path(ARGV.fetch(0, "pkg"))
  files = ENVameleon::ReleaseGems.verify!(directory)
  puts ENVameleon::ReleaseGems.checksums(files)
end
