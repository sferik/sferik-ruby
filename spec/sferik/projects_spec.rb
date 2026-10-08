# frozen_string_literal: true

RSpec.describe Sferik::Projects do
  let(:projects) { described_class.new("total" => {"downloads" => 1, "gems" => 2, "stars" => 3}) }

  it "reads the totals" do
    expect([projects.total_downloads, projects.total_gems, projects.total_stars]).to eq([1, 2, 3])
  end

  it "is a hash of its readers, not of its projects" do
    expect(projects.to_h).to include(total_downloads: 1, total_gems: 2, total_stars: 3, projects: [])
  end

  it "has no totals when the response has none" do
    expect(described_class.new({}).to_h.values_at(:total_downloads, :total_gems, :total_stars)).to eq([nil, nil, nil])
  end

  it "has no totals when the response's are null" do
    expect(described_class.new("total" => nil).total_downloads).to be_nil
  end

  it "raises InvalidResponse when the totals aren't a JSON object, without a reader being called" do
    expect { described_class.new("total" => "many") }
      .to raise_error(Sferik::InvalidResponse, "Sferik::Projects#total: expected a JSON object, got String")
  end

  it "shows how many there are, not each of them" do
    expect(projects.inspect).to eq("#<Sferik::Projects size=0 total_downloads=1 total_stars=3>")
  end

  describe "#each" do
    let(:list) { described_class.new("projects" => [{"name" => "multi_json"}, {"name" => "multi_xml"}]) }

    it "yields each project, in order" do
      names = []
      list.each { |project| names << project.name }

      expect(names).to eq(%w[multi_json multi_xml])
    end

    it "makes the projects Enumerable" do
      expect([list.first.name, list.count, list.map(&:name)]).to eq(["multi_json", 2, %w[multi_json multi_xml]])
    end

    it "returns itself with a block" do
      expect(list.each { |item| item }).to be(list)
    end

    it "returns an Enumerator without a block, which knows its size" do
      enumerator = list.each

      expect([enumerator.next, enumerator.size]).to eq([Sferik::Project.new("name" => "multi_json"), 2])
    end

    it "yields nothing when the response has no projects" do
      expect(described_class.new({}).to_a).to eq([])
    end
  end

  it "raises InvalidResponse for totals of false, which is no JSON object" do
    expect { described_class.new("total" => false) }.to raise_error(Sferik::InvalidResponse, "Sferik::Projects#total: expected a JSON object, got FalseClass")
  end
end
