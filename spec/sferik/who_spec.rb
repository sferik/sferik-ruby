# frozen_string_literal: true

RSpec.describe Sferik::Who do
  let(:who) { described_class.new("users" => [{"tty" => "ttys001", "page" => "/"}, {"tty" => "ttys002", "page" => "/talks"}]) }

  it "is a hash of its readers, not of its terminals" do
    expect(who.to_h).to eq(users: who.users, you: nil)
  end

  it "has the terminal that checked in" do
    expect(described_class.new("you" => "ttys001").you).to eq("ttys001")
  end

  it "shows how many there are, not each of them" do
    expect(who.inspect).to eq("#<Sferik::Who size=2>")
  end

  describe "#each" do
    it "yields each terminal, in order" do
      ttys = []
      who.each { |session| ttys << session.tty }

      expect(ttys).to eq(%w[ttys001 ttys002])
    end

    it "makes the terminals Enumerable" do
      expect([who.first.tty, who.size, who.map(&:page)]).to eq(["ttys001", 2, %w[/ /talks]])
    end

    it "returns itself with a block" do
      expect(who.each { |item| item }).to be(who)
    end

    it "returns an Enumerator without a block, which knows its size" do
      enumerator = who.each

      expect([enumerator.next, enumerator.size]).to eq([Sferik::Session.new("tty" => "ttys001", "page" => "/"), 2])
    end

    it "yields nothing when nobody's there" do
      expect(described_class.new({}).to_a).to eq([])
    end
  end
end
