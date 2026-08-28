# frozen_string_literal: true

require "bundler"
require "rubygems/package"
require "rubygems/resolver"
require "rubygems/resolver/spec_specification"

require_relative "native_platforms"

module ENVameleon
  class RubyGemsPackageSet < Gem::Resolver::Set
    def initialize(specifications)
      super()
      @specifications = specifications
    end

    def find_all(request)
      @specifications.filter_map do |specification|
        next unless request.match?(specification)

        Gem::Resolver::SpecSpecification.new(self, specification)
      end
    end
  end

  class BundlerArtifactSource < Bundler::Source
    attr_reader :specs

    def initialize(specifications, description)
      super()
      @description = description
      @specs = Bundler::Index.build do |index|
        specifications.each do |specification|
          specification.source = self
          index << specification
        end
      end
    end

    def to_s
      @description
    end
  end

  module GemResolution
    module_function

    def verify!(directory)
      specifications = load_specifications(directory)
      version = specifications.map(&:version).uniq.fetch(0)
      package_set = RubyGemsPackageSet.new(specifications)
      artifact_source = BundlerArtifactSource.new(specifications, "release artifacts")

      scenarios.each do |platform, ruby_version, expected_platform|
        resolvers = {
          "RubyGems" => resolve_with_rubygems(package_set, version, platform, ruby_version),
          "Bundler" => resolve_with_bundler(artifact_source, version, platform, ruby_version)
        }
        resolvers.each do |resolver, actual_platform|
          unless actual_platform == expected_platform
            abort "#{resolver}: Ruby #{ruby_version} on #{platform} resolved to #{actual_platform}, expected #{expected_platform}"
          end
        end

        puts "RubyGems and Bundler: Ruby #{ruby_version} on #{platform} resolves to #{expected_platform}"
      end
    end

    def load_specifications(directory)
      files = Dir[File.join(directory, "*.gem")].sort
      specifications = files.map { |file| Gem::Package.new(file).spec }
      platforms = specifications.map { |specification| specification.platform.to_s }
      expected_platforms = [ENVAMELEON_SOURCE_PLATFORM, *ENVAMELEON_NOOP_PLATFORMS, *ENVAMELEON_NATIVE_PLATFORMS]

      abort "Expected gem platforms #{expected_platforms.sort}, got #{platforms.sort}" unless platforms.sort == expected_platforms.sort
      abort "Gem versions differ" unless specifications.map(&:version).uniq.one?

      specifications
    end

    def scenarios
      supported_rubies = ENVAMELEON_RUBY_API_VERSIONS.map { |version| "#{version}.0" }
      next_ruby = "#{ENVAMELEON_NEXT_RUBY_API_VERSION}.0.dev"
      linux = ENVAMELEON_NATIVE_PLATFORMS.flat_map do |platform|
        supported = supported_rubies.map { |ruby_version| [platform, ruby_version, platform] }
        supported << [platform, next_ruby, ENVAMELEON_SOURCE_PLATFORM]
      end
      non_linux = {
        "arm64-darwin" => "universal-darwin",
        "x86_64-darwin" => "universal-darwin",
        "x64-mingw-ucrt" => "universal-mingw",
        "x86-mingw32" => "universal-mingw"
      }.flat_map do |platform, expected_platform|
        [supported_rubies.first, next_ruby].map do |ruby_version|
          [platform, ruby_version, expected_platform]
        end
      end

      linux + non_linux
    end

    def resolve_with_rubygems(package_set, version, platform_name, ruby_version)
      original_platforms = Gem.platforms.dup
      original_local_platform = Gem::Platform.local
      ruby_version_defined = Gem.instance_variable_defined?(:@ruby_version)
      original_ruby_version = Gem.instance_variable_get(:@ruby_version)

      platform = Gem::Platform.new(platform_name)
      Gem.platforms = [Gem::Platform::RUBY, platform]
      Gem::Platform.instance_variable_set(:@local, platform)
      Gem.instance_variable_set(:@ruby_version, Gem::Version.new(ruby_version))

      dependency = Gem::Dependency.new("envameleon", "= #{version}")
      activation = Gem::Resolver.new([dependency], package_set).resolve.fetch(0)
      activation.platform.to_s
    ensure
      Gem.platforms = original_platforms if original_platforms
      Gem::Platform.instance_variable_set(:@local, original_local_platform)
      if ruby_version_defined
        Gem.instance_variable_set(:@ruby_version, original_ruby_version)
      elsif Gem.instance_variable_defined?(:@ruby_version)
        Gem.remove_instance_variable(:@ruby_version)
      end
    end

    def resolve_with_bundler(artifact_source, version, platform_name, ruby_version)
      # Bundler has no command-line switch for resolving as a different Ruby.
      # These are the same metadata dependencies it uses for the running Ruby.
      platform = Gem::Platform.new(platform_name)
      metadata_source = BundlerArtifactSource.new(
        [
          Gem::Specification.new("Ruby\0", ruby_version),
          Gem::Specification.new("RubyGems\0", Gem::VERSION)
        ],
        "target Ruby"
      )
      dependencies = [
        Bundler::Dependency.new("envameleon", "= #{version}"),
        Bundler::Dependency.new("Ruby\0", ruby_version),
        Bundler::Dependency.new("RubyGems\0", Gem::VERSION)
      ]
      sources = {
        default: artifact_source,
        "envameleon" => artifact_source,
        "Ruby\0" => metadata_source,
        "RubyGems\0" => metadata_source
      }
      empty_specs = Bundler::SpecSet.new([])
      base = Bundler::Resolver::Base.new(
        sources,
        dependencies,
        empty_specs,
        [platform],
        locked_specs: empty_specs,
        unlock: true,
        prerelease: false,
        prefer_local: false,
        new_platforms: [platform]
      )
      resolved = Bundler::Resolver.new(base, Bundler::GemVersionPromoter.new).start
      specification = resolved.find { |candidate| candidate.name == "envameleon" }
      abort "Bundler did not resolve envameleon" unless specification

      specification.platform.to_s
    end
  end
end

ENVameleon::GemResolution.verify!(File.expand_path(ARGV.fetch(0, "pkg")))
