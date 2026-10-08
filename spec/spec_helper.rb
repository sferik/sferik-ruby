# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant") || RUBY_ENGINE.eql?("jruby")
  require "simplecov"

  SimpleCov.start "strict"
end

require "sferik"
require "rspec"
require "webmock/rspec"

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.before { Sferik.reset }
  # Each example starts with no connection open: a thread keeps the ones it opens, and they all run on one
  config.before { Thread.current[:sferik_connections] = nil }
end

# The path of a fixture: a response saved from the API
def fixture_path(name)
  File.expand_path("fixtures/#{name}", __dir__)
end

# The contents of a fixture
def fixture(name)
  File.read(fixture_path(name))
end

# Stub a GET of a path on sferik.net that asks for a media type, answering with a fixture, as UTF-8 like the site does
def stub_get(path, fixture_name, accept: "application/json", content_type: "#{accept}; charset=utf-8")
  stub_request(:get, "https://sferik.net#{path}")
    .with(headers: {"Accept" => accept})
    .to_return(body: fixture(fixture_name), headers: {"Content-Type" => content_type})
end
