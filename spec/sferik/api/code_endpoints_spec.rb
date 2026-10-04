# frozen_string_literal: true

RSpec.describe Sferik::API::CodeEndpoints do
  let(:client) { Sferik::Client.new }

  describe "#contributions" do
    before { stub_get("/contributions", "contributions.json") }

    it "returns the totals" do
      contributions = client.contributions

      expect(contributions).to have_attributes(total: Integer, longest_streak: Integer, since: 2008, live?: contributions.attributes.fetch("live"), command: /git log/)
    end

    it "returns when the numbers are from" do
      expect(client.contributions.as_of).to be_a(Time).and(be_frozen).and(be_between(Time.utc(2026, 10, 1), Time.now))
    end

    it "returns a year of days" do
      expect(client.contributions.days.size).to be >= 365
    end

    it "returns each day's date, count, and level" do
      expect(client.contributions.days.first).to have_attributes(date: Date, count: Integer, level: be_between(0, 4))
    end

    it "returns the latest push" do
      expect(client.contributions.last_push).to have_attributes(repo: %r{/}, sha: /\A\h{7,40}\z/, at: Time)
    end

    it "raises InvalidResponse itself for a response that isn't what the API documents, however deep" do
      stub_request(:get, "https://sferik.net/contributions").to_return(body: '{"contributions":[{"date":"soon"}]}', headers: {"Content-Type" => "application/json"})

      expect { client.contributions }.to raise_error(Sferik::InvalidResponse, 'Sferik::Day#date: "soon" isn\'t an ISO 8601 date')
    end
  end

  describe "#projects" do
    before { stub_get("/src", "src.json") }

    it "returns the totals" do
      expect(client.projects).to have_attributes(total_downloads: be > 5_000_000_000, total_gems: Integer, total_stars: Integer,
        more: %r{\Ahttps://github.com/sferik}, command: "ls -lS ~/src", live?: be(true).or(be(false)))
    end

    it "returns when the downloads are from" do
      expect(client.projects.as_of).to be_a(Time).and(be_frozen).and(be_between(Time.utc(2026, 10, 1), Time.now))
    end

    it "returns projects, most downloaded first" do
      expect(client.projects.projects.first).to have_attributes(name: "multi_json", description: String, downloads: Integer, stars: Integer, url: String)
    end

    it "returns nil downloads for a project that isn't a gem" do
      expect(client.projects.projects.map(&:downloads)).to include(nil)
    end
  end
end
