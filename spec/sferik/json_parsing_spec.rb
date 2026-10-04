# frozen_string_literal: true

RSpec.describe "Sferik::JSONParsing" do
  let(:parser) { Class.new { include Sferik.const_get(:JSONParsing) }.new }

  def parse(body)
    parser.send(:parse_json, body)
  end

  it "parses a JSON object" do
    expect(parse('{"command":"whoami"}')).to eq("command" => "whoami")
  end

  it "deep-freezes what it parses" do
    parsed = parse('{"paths":{"/whoami":["get"]}}')

    expect([parsed, parsed["paths"], parsed["paths"]["/whoami"], parsed["paths"]["/whoami"].first]).to all(be_frozen)
  end

  it "raises InvalidResponse for JSON that doesn't parse, with the parser's message" do
    expect { parse("<html>") }.to raise_error(Sferik::InvalidResponse, /\ACouldn't parse the response as JSON: \S/)
  end

  it "parses JSON in another charset" do
    expect(parse('{"command":"whoami"}'.encode(Encoding::UTF_16LE))).to eq("command" => "whoami")
  end

  it "raises InvalidResponse for a body that isn't valid in its charset" do
    body = String.new("\x00\xD8x", encoding: Encoding::UTF_16LE)

    expect { parse(body) }.to raise_error(Sferik::InvalidResponse, /\ACouldn't parse the response as JSON: .*UTF-16LE/)
  end

  it "raises InvalidResponse for a body in a charset that can't be read as text" do
    body = String.new("{}", encoding: Encoding::UTF_7)

    expect { parse(body) }.to raise_error(Sferik::InvalidResponse, /\ACouldn't parse the response as JSON: .*UTF-7/)
  end

  it "raises InvalidResponse for JSON that isn't an object" do
    expect { parse("[]") }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object, got Array")
  end
end
