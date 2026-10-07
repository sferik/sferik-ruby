# frozen_string_literal: true

RSpec.describe Sferik::API::TalkEndpoints do
  let(:client) { Sferik::Client.new }

  describe "#talks" do
    before { stub_get("/talks", "talks.json") }

    it "returns where the slides are" do
      expect(client.talks).to have_attributes(speaker_deck: "https://speakerdeck.com/sferik", command: %r{\Als -l?t ~/talks})
    end

    it "marks the talks the home page shows" do
      expect(client.talks.count(&:featured?)).to eq(6)
    end

    it "returns talks" do
      expect(client.talks.find { |t| t.title.eql?("Writing Fast Ruby") }).to have_attributes(event: String, location: String,
        date: Date.new(2015, 4, 1), slides: String)
    end

    it "returns where each talk's location is" do
      talks = client.talks

      expect(talks.places.fetch(talks.first.location)).to have_attributes(lat: Numeric, lon: Numeric, country: String)
    end

    it "returns a place for every talk" do
      talks = client.talks

      expect(talks.map(&:location) - talks.places.keys).to eq([])
    end

    it "returns the podcasts with them" do
      stub_get("/podcasts", "podcasts.json")

      expect(client.talks.podcasts).to eq(client.podcasts)
    end
  end

  describe "#talks_feed" do
    before { stub_get("/talks.atom", "talks.atom", accept: "application/atom+xml") }

    it "asks for the Atom feed" do
      expect(client.talks_feed).to start_with(%(<?xml version="1.0" encoding="utf-8"?>\n<feed xmlns="http://www.w3.org/2005/Atom">))
    end

    it "returns an entry for each talk" do
      expect(client.talks_feed.scan("<entry>").size).to be > 1
    end
  end

  describe "#podcasts" do
    before { stub_get("/podcasts", "podcasts.json") }

    it "returns podcasts" do
      expect(client.podcasts.first).to have_attributes(title: String, show: String, date: Date.new(2016, 2, 1), url: String)
    end

    it "returns them frozen" do
      expect(client.podcasts).to be_frozen.and(all(be_a(Sferik::Podcast)))
    end
  end
end
