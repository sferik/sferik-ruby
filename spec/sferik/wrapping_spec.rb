# frozen_string_literal: true

RSpec.describe "Sferik::Wrapping" do
  # A resource with one reader of each kind that wraps its value
  let(:example) do
    stub_const("Sferik::Wrapped", Class.new(Sferik::Resource) do
      attribute :push, type: Sferik::Push
      attribute :raw
      list :pushes, type: Sferik::Push
      list :tags
      dictionary :places, type: Sferik::Place
      timestamp :at, Time
      timestamp :on, Date
    end)
  end

  it "is private to the resources that include it" do
    expect(Sferik::Resource.private_instance_methods).to include(*Sferik.const_get(:Wrapping).private_instance_methods(false))
  end

  describe "#wrap" do
    it "wraps a value in its type" do
      expect(example.new("push" => {"repo" => "a/b"}).push).to eq(Sferik::Push.new("repo" => "a/b"))
    end

    it "leaves a missing value nil" do
      expect(example.new({}).push).to be_nil
    end

    it "leaves a value without a type as it is" do
      expect(example.new("raw" => {"a" => 1}).raw).to eq("a" => 1)
    end

    it "raises InvalidResponse for something other than an object" do
      expect { example.new("push" => [{}]) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Push, got Array")
    end
  end

  describe "#wrap_list" do
    it "wraps each value in its type, frozen" do
      expect(example.new("pushes" => [{"repo" => "a/b"}]).pushes).to eq([Sferik::Push.new("repo" => "a/b")]).and(be_frozen)
    end

    it "leaves the values of a list without a type as they are" do
      expect(example.new("tags" => ["a"]).tags).to eq(["a"])
    end

    it "raises InvalidResponse for a list that isn't one, naming its reader" do
      expect { example.new("pushes" => {"repo" => "a/b"}) }.to raise_error(Sferik::InvalidResponse, "Sferik::Wrapped#pushes: expected a JSON array, got Hash")
    end

    it "raises InvalidResponse for a list of something other than objects" do
      expect { example.new("pushes" => ["x"]) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Push, got String")
    end
  end

  describe "#wrap_dictionary" do
    it "wraps each value in its type, frozen" do
      expect(example.new("places" => {"Barcelona" => {"country" => "Spain"}}).places).to eq("Barcelona" => Sferik::Place.new("country" => "Spain")).and(be_frozen)
    end

    it "raises InvalidResponse for a dictionary that isn't one, naming its reader" do
      expect { example.new("places" => [1]) }.to raise_error(Sferik::InvalidResponse, "Sferik::Wrapped#places: expected a JSON object, got Array")
    end

    it "raises InvalidResponse for a dictionary of something other than objects" do
      expect { example.new("places" => {"Barcelona" => 1}) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Place, got Integer")
    end
  end

  describe "#wrap_timestamp" do
    it "parses a time" do
      expect(example.new("at" => "2026-10-01T12:00:00Z").at).to eq(Time.utc(2026, 10, 1, 12))
    end

    it "parses a date" do
      expect(example.new("on" => "2026-10-01").on).to eq(Date.new(2026, 10, 1))
    end

    it "leaves a missing one nil" do
      expect([example.new({}).at, example.new("on" => nil).on]).to eq([nil, nil])
    end

    it "freezes a time and a date" do
      expect(example.new("at" => "2026-10-01T12:00:00Z", "on" => "2026-10-01")).to have_attributes(at: be_frozen, on: be_frozen)
    end

    it "raises InvalidResponse for a time that isn't one, naming its reader" do
      expect { example.new("at" => "soon") }.to raise_error(Sferik::InvalidResponse, 'Sferik::Wrapped#at: "soon" isn\'t an ISO 8601 time')
    end

    it "raises InvalidResponse for a date that isn't one, naming its reader" do
      expect { example.new("on" => "soon") }.to raise_error(Sferik::InvalidResponse, 'Sferik::Wrapped#on: "soon" isn\'t an ISO 8601 date')
    end

    it "raises InvalidResponse for one that isn't a string" do
      expect { example.new("at" => 1) }.to raise_error(Sferik::InvalidResponse, "Sferik::Wrapped#at: 1 isn't an ISO 8601 time")
    end
  end

  describe "#deep_freeze" do
    it "freezes the attributes and everything in them" do
      raw = example.new("raw" => {"list" => [{"a" => +"b"}]}).attributes

      expect([raw, raw["raw"], raw["raw"]["list"], raw["raw"]["list"].first, raw["raw"]["list"].first["a"]]).to all(be_frozen)
    end

    it "keeps every value as it was" do
      given = {"raw" => {"list" => [{"a" => "b"}, 1, nil, true], "name" => "x"}}

      expect(example.new(given).attributes).to eq(given)
    end

    it "freezes copies, not what it was given" do
      given = {"raw" => {"list" => [+"a"]}}
      example.new(given)

      expect([given, given["raw"], given["raw"]["list"], given["raw"]["list"].first].map(&:frozen?)).to eq([false, false, false, false])
    end

    it "keeps a string that's already frozen, without copying it" do
      title = "Writing Fast Ruby"

      expect(example.new("raw" => title).raw).to be(title)
    end

    it "raises ArgumentError for a key that isn't a String, however deep" do
      expect { example.new("raw" => {"list" => [{a: 1}]}) }.to raise_error(ArgumentError, "key must be String, not :a")
    end

    it "takes a key of a class of String" do
      expect(example.new(Class.new(String).new("raw") => 1).raw).to eq(1)
    end

    it "leaves a value that isn't one of JSON's as it is, not frozen" do
      value = Object.new

      expect(example.new("raw" => value).raw).to be(value).and(satisfy { |raw| !raw.frozen? })
    end
  end
end
