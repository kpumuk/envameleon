# frozen_string_literal: true

require_relative "verify_release_gems"

abort "Releases must run in kpumuk/envameleon" unless ENV.fetch("GITHUB_REPOSITORY") == "kpumuk/envameleon"
abort "Releases must run from the main branch" unless ENV.fetch("GITHUB_REF") == "refs/heads/main"

specification = Gem::Specification.load("envameleon.gemspec")
abort "Could not load envameleon.gemspec" unless specification

release_tag = "v#{specification.version}"
tag_exists = system(
  "git", "rev-parse", "--verify", "--quiet", "refs/tags/#{release_tag}",
  out: File::NULL
)
abort "#{release_tag} already exists; bump the gem version first" if tag_exists

gem_files = ENVameleon::ReleaseGems.verify!("pkg")
gem_versions = gem_files.map { |file| Gem::Package.new(file).spec.version }.uniq
abort "Artifacts do not match #{specification.version}" unless gem_versions == [specification.version]

File.write("SHA256SUMS", ENVameleon::ReleaseGems.checksums(gem_files))

File.open(ENV.fetch("GITHUB_ENV"), "a") do |file|
  file.puts "RELEASE_TAG=#{release_tag}"
end
