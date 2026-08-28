# frozen_string_literal: true

specification = Gem::Specification.load("envameleon.gemspec")
abort "Could not load envameleon.gemspec" unless specification

release_tag = "v#{specification.version}"
tag_exists = system(
  "git", "rev-parse", "--verify", "--quiet", "refs/tags/#{release_tag}",
  out: File::NULL
)
abort "#{release_tag} already exists; bump the gem version first" if tag_exists

File.open(ENV.fetch("GITHUB_ENV"), "a") do |file|
  file.puts "GEM_FILE=#{specification.file_name}"
  file.puts "RELEASE_TAG=#{release_tag}"
end
