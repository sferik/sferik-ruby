# frozen_string_literal: true

RSpec.describe Sferik::Collection do
  let(:talks) { Sferik::Talks.new("talks" => [{"title" => "a"}, {"title" => "b"}, {"title" => "c"}]) }
  let(:none) { Sferik::Projects.new({}) }

  it "is what Projects, Talks, and Who are" do
    expect([Sferik::Projects, Sferik::Talks, Sferik::Who]).to all(include(described_class))
  end

  it "counts them" do
    expect([talks.size, talks.length, none.size, none.length]).to eq([3, 3, 0, 0])
  end

  it "says whether there are none" do
    expect([talks.empty?, none.empty?]).to eq([false, true])
  end

  it "returns the last one" do
    expect([talks.last, none.last]).to eq([Sferik::Talk.new("title" => "c"), nil])
  end

  it "returns the last few" do
    expect(talks.last(2).map(&:title)).to eq(%w[b c])
  end

  it "returns the one at an index" do
    expect([talks[0].title, talks[-1].title, talks[3]]).to eq(["a", "c", nil])
  end

  it "returns those from a start, for a length" do
    expect(talks[1, 2].map(&:title)).to eq(%w[b c])
  end

  it "returns those in a range" do
    expect(talks[0..1].map(&:title)).to eq(%w[a b])
  end

  it "matches an array pattern" do
    matched = case talks
    in [first, *, last] then [first.title, last.title]
    end

    expect(matched).to eq(%w[a c])
  end

  it "deconstructs to none when there are none" do
    expect(none.deconstruct).to eq([])
  end

  it "reads the projects of Projects" do
    projects = Sferik::Projects.new("projects" => [{"name" => "multi_json"}, {"name" => "multi_xml"}])

    expect([projects.size, projects.last.name, projects[0].name]).to eq([2, "multi_xml", "multi_json"])
  end
end
