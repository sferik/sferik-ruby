# frozen_string_literal: true

RSpec.describe Sferik::Talks do
  let(:talks) { described_class.new("talks" => [{"title" => "Writing Fast Ruby"}, {"title" => "Mutation Testing"}]) }

  it "is a hash of its readers, not of its talks" do
    expect(described_class.new("speakerDeck" => "https://speakerdeck.com/sferik").to_h).to include(talks: [], podcasts: [], speaker_deck: "https://speakerdeck.com/sferik")
  end

  it "shows how many there are, not each of them" do
    expect(talks.inspect).to eq("#<Sferik::Talks size=2 speaker_deck=nil>")
  end

  describe "#each" do
    it "yields each talk, in order" do
      titles = []
      talks.each { |talk| titles << talk.title }

      expect(titles).to eq(["Writing Fast Ruby", "Mutation Testing"])
    end

    it "makes the talks Enumerable" do
      expect([talks.first.title, talks.count, talks.map(&:title)]).to eq(["Writing Fast Ruby", 2, ["Writing Fast Ruby", "Mutation Testing"]])
    end

    it "returns itself with a block" do
      expect(talks.each { |item| item }).to be(talks)
    end

    it "returns an Enumerator without a block, which knows its size" do
      enumerator = talks.each

      expect([enumerator.next, enumerator.size]).to eq([Sferik::Talk.new("title" => "Writing Fast Ruby"), 2])
    end

    it "yields nothing when the response has no talks" do
      expect(described_class.new({}).to_a).to eq([])
    end
  end
end
