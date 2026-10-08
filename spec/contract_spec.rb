# frozen_string_literal: true

require "json"
require "json_schemer"

# The contract between the library and the site: spec/fixtures/openapi.json is the site's own description of its API,
# saved with the other fixtures by `rake fixtures`. Every fixture must fit its schema there, and every key a reader
# reads must be one its schema documents, so a change to the site that the library hasn't caught up with fails here
# rather than in production.
module Contract
  DOCUMENT = JSON.parse(File.read(File.expand_path("fixtures/openapi.json", __dir__)))

  # Each fixture, and the schema of the response it was saved from
  FIXTURES = {
    "home.json" => "Home", "whoami.json" => "Whoami", "contributions.json" => "Contributions", "src.json" => "Src",
    "name.json" => "NameChange", "talks.json" => "Talks", "podcasts.json" => "Podcasts", "finger.json" => "Finger", "resume.json" => "Resume",
    "dependency.json" => "Dependency", "who.json" => "Users", "check_in.json" => "Who", "version.json" => "Version",
    "webfinger.json" => "WebFinger"
  }.freeze

  # Each resource class, and where its schema is in the document
  SCHEMAS = {
    Sferik::Home => "Home", Sferik::Home::Profile => "Home/properties/profile",
    Sferik::Home::Section => "Home/properties/modules/items", Sferik::Home::Pages => "Home/properties/pages",
    Sferik::Whoami => "Whoami", Sferik::Block => "Block", Sferik::Contributions => "Contributions", Sferik::Day => "Day",
    Sferik::Push => "Push", Sferik::Projects => "Src", Sferik::Project => "Project", Sferik::NameChange => "NameChange",
    Sferik::Talks => "Talks", Sferik::Talk => "Talk", Sferik::Podcast => "Podcast",
    Sferik::Finger => "Finger", Sferik::SocialProfile => "SocialProfile", Sferik::Resume => "Resume",
    Sferik::Resume::Basics => "Resume/properties/basics", Sferik::Resume::Location => "Resume/properties/basics/properties/location",
    Sferik::Resume::Profile => "Resume/properties/basics/properties/profiles/items",
    Sferik::Resume::Work => "Resume/properties/work/items", Sferik::Resume::Volunteer => "Resume/properties/volunteer/items",
    Sferik::Resume::Education => "Resume/properties/education/items", Sferik::Resume::Award => "Resume/properties/awards/items",
    Sferik::Resume::Patent => "Resume/properties/patents/items", Sferik::Resume::Project => "Resume/properties/projects/items",
    Sferik::Resume::Skill => "Resume/properties/skills/items", Sferik::Resume::Speaking => "Resume/properties/speaking",
    Sferik::Resume::Meta => "Resume/properties/meta", Sferik::Dependency => "Dependency", Sferik::Figure => "Figure",
    Sferik::Place => "Place", Sferik::Who => "Who", Sferik::Session => "Session", Sferik::Deployment => "Version",
    Sferik::WebFinger => "WebFinger", Sferik::WebFinger::Link => "WebFinger/properties/links/items"
  }.freeze

  module_function

  # The errors validating a fixture against a schema
  def errors(file, name)
    JSONSchemer.openapi(DOCUMENT).schema(name).validate(JSON.parse(File.read(File.expand_path("fixtures/#{file}", __dir__)))).map { |e| e.fetch("error") }
  end

  # Follow a JSON pointer, and any $ref it lands on, to a schema in the document
  def resolve(pointer)
    schema = pointer.delete_prefix("#/").split("/").reduce(DOCUMENT) { |node, key| node.fetch(key) }
    schema.key?("$ref") ? resolve(schema.fetch("$ref")) : schema
  end

  # The properties a schema documents, including those of each schema it may be one of
  def properties(schema)
    options = schema.fetch("oneOf", []).map { |option| option.key?("$ref") ? resolve(option.fetch("$ref")) : option }
    schema.fetch("properties", {}).keys + options.flat_map { |option| properties(option) }
  end
end

RSpec.describe Contract do
  Contract::FIXTURES.each do |file, name|
    it "#{file} fits the #{name} schema" do
      expect(described_class.errors(file, name)).to eq([])
    end
  end

  Contract::SCHEMAS.each do |resource, pointer|
    it "#{resource} reads only keys the #{pointer} schema documents" do
      expect(resource.__send__(:keys) - described_class.properties(described_class.resolve("#/components/schemas/#{pointer}"))).to eq([])
    end
  end

  it "Sferik::Projects reads only totals the Src schema documents" do
    expect(described_class.resolve("#/components/schemas/Src/properties/total").fetch("properties").keys).to include("downloads", "gems", "stars")
  end

  it "Sferik::Who reads every key of who's reading, which checking in adds one to" do
    properties = %w[Users Who].map { |name| described_class.properties(described_class.resolve("#/components/schemas/#{name}")) }

    expect(properties).to eq([%w[users], %w[you users]])
  end

  it "covers every resource class" do
    named = Sferik::Resource.subclasses.select { |klass| klass.name && Object.const_defined?(klass.name) && Object.const_get(klass.name).equal?(klass) }

    expect(named - Contract::SCHEMAS.keys).to eq([])
  end
end
