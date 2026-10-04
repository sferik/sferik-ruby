# frozen_string_literal: true

RSpec.describe Sferik::Resume do
  let(:resume) { described_class.new("basics" => {"name" => "Erik Berlin"}, "work" => [{"name" => "Twitter"}]) }

  describe "#name" do
    it "is the name in the basics" do
      expect(resume.name).to eq("Erik Berlin")
    end

    it "is nil without basics" do
      expect(described_class.new({}).name).to be_nil
    end
  end

  describe "#last_modified" do
    it "is the date in the meta" do
      expect(described_class.new("meta" => {"lastModified" => "2026-10-01"}).last_modified).to eq(Date.new(2026, 10, 1))
    end

    it "is nil without meta" do
      expect(resume.last_modified).to be_nil
    end
  end

  describe "#to_h" do
    it "has the name and when it last changed, after the sections" do
      expect(described_class.attribute_names.last(3)).to eq(%i[meta name last_modified])
    end
  end

  describe "pattern matching" do
    it "binds the name and when it last changed" do
      matched = case described_class.new("basics" => {"name" => "Erik Berlin"}, "meta" => {"lastModified" => "2026-10-01"})
      in {name:, last_modified:} then [name, last_modified]
      end

      expect(matched).to eq(["Erik Berlin", Date.new(2026, 10, 1)])
    end
  end

  describe "#inspect" do
    it "shows only the name" do
      expect(resume.inspect).to eq('#<Sferik::Resume name="Erik Berlin">')
    end
  end
end
