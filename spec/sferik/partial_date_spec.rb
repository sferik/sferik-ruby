# frozen_string_literal: true

RSpec.describe "Sferik::PartialDate" do
  let(:partial_date) { Sferik.const_get(:PartialDate) }

  describe ".iso8601" do
    it "parses a day" do
      expect(partial_date.iso8601("2014-04-22")).to eq(Date.new(2014, 4, 22))
    end

    it "parses a month as its first day" do
      expect(partial_date.iso8601("2015-11")).to eq(Date.new(2015, 11, 1))
    end

    it "parses a month without relying on Date.iso8601 to, since JRuby's doesn't" do
      allow(Date).to receive(:iso8601).and_wrap_original do |original, value|
        raise Date::Error, "invalid date" if value.match?(/\A\d{4}-\d{2}\z/)

        original.call(value)
      end

      expect(partial_date.iso8601("2015-11")).to eq(Date.new(2015, 11, 1))
    end

    it "parses a year as its first day" do
      expect(partial_date.iso8601("2026")).to eq(Date.new(2026, 1, 1))
    end

    it "leaves five digits to ISO 8601, which reads them as a two-digit year and a day of it" do
      expect(partial_date.iso8601("20261")).to eq(Date.new(2020, 9, 17))
    end

    it "reads a year only from the whole value" do
      expect(partial_date.iso8601("12026")).to eq(Date.new(2012, 1, 26))
    end

    it "rejects what isn't a date" do
      expect { partial_date.iso8601("soon") }.to raise_error(Date::Error)
    end
  end
end
