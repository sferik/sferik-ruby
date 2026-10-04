# frozen_string_literal: true

RSpec.describe Sferik::Block do
  it "reads the type and the HTML of a paragraph, and nothing else" do
    expect(described_class.new("type" => "p", "html" => "<em>Hi</em>").to_h).to eq(type: "p", html: "<em>Hi</em>")
  end
end
