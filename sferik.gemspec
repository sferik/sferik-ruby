# frozen_string_literal: true

require_relative "lib/sferik/version"

Gem::Specification.new do |spec|
  spec.name = "sferik"
  spec.version = Sferik::VERSION
  spec.authors = ["Erik Berlin"]
  spec.email = ["sferik@gmail.com"]

  spec.summary = "Ruby wrapper for the sferik.net API"
  spec.description = "A client for the sferik.net API: Erik Berlin's bio, GitHub contributions, projects, talks, " \
    "and resume (as JSON Resume, LaTeX, or PDF), with immutable response objects"
  spec.homepage = "https://github.com/sferik/sferik-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/sferik-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/sferik-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/sferik/",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/sferik-ruby"
  }

  spec.files = Dir.glob([".yardopts", "exe/*", "lib/**/*.rb", "sig/*.rbs", "sig/manifest.yaml", "{CHANGELOG,LICENSE,README}.md"], base: __dir__)
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = ["sferik"]
end
