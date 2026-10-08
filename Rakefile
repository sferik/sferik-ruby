# frozen_string_literal: true

require "bundler/gem_tasks"

# Leave the gem push to GitHub Actions: the tag the release task pushes runs .github/workflows/push_gem.yml, which
# checks the tag with CI and then runs this task there, with the push, to push the gem with trusted publishing
unless ENV["GITHUB_ACTIONS"]
  Rake::Task["release"].clear
  desc "Build the gem and push a tag, which CI pushes the gem for (see .github/workflows/push_gem.yml)"
  task release: %w[build release:guard_clean release:source_control_push]
end
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Run specs"
task test: :spec

require "standard/rake"
require "rubocop/rake_task"

RuboCop::RakeTask.new

begin
  require "steep/rake_task"

  Steep::RakeTask.new(:steep)
rescue LoadError
  desc "Run type checker (unavailable on this platform)"
  task :steep do
    warn "Steep is not available on #{RUBY_ENGINE}"
  end
end

# Validate the signatures themselves, against the standard libraries sig/manifest.yaml names, which are the ones rbs
# collection loads for code that depends on this gem
desc "Validate the RBS signatures (skipped on Rubies without RBS)"
task :rbs do
  if Gem.loaded_specs.key?("rbs")
    require "yaml"

    libraries = YAML.load_file("sig/manifest.yaml").fetch("dependencies").map { |dependency| dependency.fetch("name") }
    sh "bundle exec rbs -I sig #{libraries.map { |library| "-r #{library}" }.join(" ")} validate"
  else
    warn "RBS is not available on #{RUBY_ENGINE}"
  end
end

# The responses the specs stub requests with, by fixture file, and the path and media type each is fetched with
FIXTURES = {
  "home.json" => "/", "whoami.json" => "/whoami", "contributions.json" => "/contributions", "src.json" => "/src",
  "name.json" => "/name", "talks.json" => "/talks", "podcasts.json" => "/podcasts", "finger.json" => "/finger", "resume.json" => "/resume",
  "dependency.json" => "/dependency", "who.json" => "/who", "openapi.json" => "/openapi.json", "version.json" => "/version",
  "webfinger.json" => "/.well-known/webfinger?resource=acct:sferik@sferik.net"
}.freeze

# The fixtures that aren't JSON, and what each is asked for as
OTHER_FIXTURES = {
  "whoami.txt" => ["/whoami", "text/plain"], "finger.vcf" => ["/finger", "text/vcard"], "talks.atom" => ["/talks.atom", "application/atom+xml"],
  "signature.txt" => ["/.signature", "text/plain"]
}.freeze

desc "Save the API's responses as the specs' fixtures (HOST=http://localhost:3745 for a local copy of the site)"
task :fixtures do
  require "securerandom"
  require_relative "lib/sferik"

  client = Sferik::Client.new(host: ENV.fetch("HOST", Sferik.host))
  FIXTURES.each { |file, path| File.write("spec/fixtures/#{file}", client.get(path)) }
  OTHER_FIXTURES.each { |file, (path, accept)| File.write("spec/fixtures/#{file}", client.get(path, accept:)) }
  # Checking in logs a terminal in to the site, for three minutes
  File.write("spec/fixtures/check_in.json", client.post("/who?#{URI.encode_www_form(token: SecureRandom.uuid, page: "/")}"))
  puts "Saved #{FIXTURES.size + OTHER_FIXTURES.size + 1} fixtures from #{client.host}"
end

# Where two JSON documents differ, as JSON pointers: an object is compared key by key, and anything else as a whole
def drift_between(saved, live, pointer = "")
  return (saved == live) ? [] : [pointer] unless saved.is_a?(Hash) && live.is_a?(Hash)

  (saved.keys | live.keys).flat_map { |key| drift_between(saved[key], live[key], "#{pointer}/#{key}") }
end

desc "Check the saved OpenAPI description against the live site's (HOST=http://localhost:3745 for a local copy)"
task :drift do
  require "json"
  require_relative "lib/sferik"

  client = Sferik::Client.new(host: ENV.fetch("HOST", Sferik.host))
  changes = drift_between(JSON.parse(File.read("spec/fixtures/openapi.json")), client.openapi)
  abort "#{client.host} has changed since the fixtures were saved:\n#{changes.map { |pointer| "  #{pointer}" }.join("\n")}\nRun `rake fixtures`." if changes.any?
  puts "The fixtures are up to date with #{client.host}"
rescue Sferik::NetworkError, Sferik::ServerError => e
  warn "Couldn't check for drift: #{e.message}" # the site being down isn't the API changing
end

desc "Run mutation tests (skipped on Rubies without Mutant)"
task :mutant do
  if Gem.loaded_specs.key?("mutant-rspec")
    sh "bundle exec mutant run"
  else
    warn "Mutant is not available on #{RUBY_ENGINE}"
  end
end

require "yard"

YARD::Rake::YardocTask.new(:yard) do |t|
  t.files = ["lib/**/*.rb"]
  t.options = ["--no-private", "--hide-api", "private"]
end

require "yardstick/rake/measurement"
require "yardstick/rake/verify"

Yardstick::Rake::Measurement.new(:yardstick_measure) do |measurement|
  measurement.output = "doc/coverage.txt"
end

Yardstick::Rake::Verify.new(:yardstick) do |verify|
  verify.threshold = 100
end

desc "Run linters"
task lint: %i[rubocop standard]

task default: %i[spec lint mutant rbs steep yardstick]
