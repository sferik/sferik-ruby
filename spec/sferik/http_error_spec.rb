# frozen_string_literal: true

RSpec.describe Sferik::HTTPError do
  def error(body:, reason: "Internal Server Error", type: "text/plain; charset=utf-8", message: nil)
    described_class.new(message, code: 500, reason:, headers: {"content-type" => type}.compact, body:)
  end

  it "uses a plain-text body, stripped, as the message" do
    expect(error(body: "  Details\n").message).to eq("Details")
  end

  it "replaces the bytes of a plain-text body that aren't valid in its charset" do
    expect(error(body: "caf\xE9 closed").message).to eq("caf\uFFFD closed")
  end

  it "uses the status line when a body that isn't valid in its charset isn't plain text" do
    expect(error(body: "<p>caf\xE9</p>", type: "text/html").message).to eq("500 Internal Server Error")
  end

  it "has a message in UTF-8 for a plain-text body in another charset" do
    message = error(body: "café closed\n".encode(Encoding::UTF_16LE), type: "text/plain; charset=utf-16le").message

    expect([message, message.encoding]).to eq(["café closed", Encoding::UTF_8])
  end

  it "replaces the bytes of a body in another charset that aren't valid in it" do
    body = String.new("\x00\xD8x", encoding: Encoding::UTF_16LE)

    expect(error(body:, type: "text/plain; charset=utf-16le").message).to eq("�")
  end

  it "replaces the characters of a body in another charset that UTF-8 doesn't have" do
    body = String.new("caf\x81 closed", encoding: Encoding::WINDOWS_1252)

    expect(error(body:, type: "text/plain; charset=windows-1252").message).to eq("caf� closed")
  end

  it "takes a binary plain-text body, which names no charset, for UTF-8" do
    message = error(body: "café closed".b, type: "text/plain").message

    expect([message, message.encoding]).to eq(["café closed", Encoding::UTF_8])
  end

  it "replaces the bytes of a binary body that aren't valid UTF-8" do
    expect(error(body: "caf\xE9 closed".b, type: "text/plain").message).to eq("caf� closed")
  end

  it "uses the error a binary JSON body names" do
    expect(error(body: '{"error":"café closed"}'.b, type: "application/json").message).to eq("café closed")
  end

  it "uses the status line when the body is in a charset that can't be read as text" do
    body = String.new("Details", encoding: Encoding::UTF_7)

    expect(error(body:, type: "text/plain; charset=utf-7").message).to eq("500 Internal Server Error")
  end

  it "uses only the code for such a body when there's no status message" do
    expect(error(body: String.new("Details", encoding: Encoding::UTF_7), reason: "").message).to eq("500")
  end

  it "keeps the body in its own charset" do
    body = "café".encode(Encoding::UTF_16LE)

    expect(error(body:, type: "text/plain; charset=utf-16le").body).to eq(body).and(have_attributes(encoding: Encoding::UTF_16LE))
  end

  it "uses the error a JSON body names" do
    expect(error(body: %({"error":"Not Found","path":"/nope"}\n), type: "application/json").message).to eq("Not Found")
  end

  it "uses the status line when a JSON object names no error" do
    expect(error(body: '{"path":"/nope"}', type: "application/json").message).to eq("500 Internal Server Error")
  end

  it "uses the status line when the error a JSON body names isn't a string" do
    expect(error(body: '{"error":{"code":1}}', type: "application/json").message).to eq("500 Internal Server Error")
  end

  it "uses the status line when the body is JSON, but not an object" do
    expect(error(body: '["error"]', type: "application/json").message).to eq("500 Internal Server Error")
  end

  it "uses the status line, not a page of HTML" do
    expect(error(body: "<!doctype html><title>Bad Gateway</title>", type: "text/html").message).to eq("500 Internal Server Error")
  end

  it "uses the status line when the response names no type" do
    expect(error(body: "Details", type: nil).message).to eq("500 Internal Server Error")
  end

  it "uses the status line when the body is empty" do
    expect(error(body: " \n").message).to eq("500 Internal Server Error")
  end

  it "uses only the code when there's no status message" do
    expect(error(body: "", reason: "").message).to eq("500")
  end

  it "uses a message it is given, not what the response says" do
    expect(error(body: "Details", message: "Refused").message).to eq("Refused")
  end

  {"Text/Plain" => "in any case", "text/plain" => "without parameters", "text/plain ; charset=utf-8" => "with a space before its parameters"}.each do |type, how|
    it "takes a body for plain text when the type is named #{how}" do
      expect(error(body: "Details", type:).message).to eq("Details")
    end
  end

  ["text/plainer", "application/text/plain", "text/html\ntext/plain", "text/plain charset"].each do |type|
    it "doesn't take a body of #{type.inspect} for plain text" do
      expect(error(body: "Details", type:).message).to eq("500 Internal Server Error")
    end
  end

  it "keeps the code, headers, and body" do
    expect(error(body: "Details")).to have_attributes(code: 500, headers: {"content-type" => "text/plain; charset=utf-8"}, body: "Details")
  end

  it "freezes its headers and body" do
    expect(error(body: +"Details")).to have_attributes(headers: be_frozen, body: be_frozen)
  end

  it "uses only the reason when there's no code" do
    expect(described_class.new(reason: " Gone ").message).to eq("Gone")
  end

  it "has no code, headers, or body when it's given none, and the name of its class as its message" do
    expect(described_class.new).to have_attributes(code: nil, headers: {}, body: "", message: "Sferik::HTTPError")
  end

  it "has the name of its class as its message when a charset that can't be read as text is all it has" do
    expect(described_class.new(body: String.new("Details", encoding: Encoding::UTF_7)).message).to eq("Sferik::HTTPError")
  end

  {Sferik::ClientError => "400 Bad Request", Sferik::NotFound => "404 Not Found", Sferik::NotAcceptable => "406 Not Acceptable", Sferik::TooManyRequests => "429 Too Many Requests",
   Sferik::ServerError => "500 Internal Server Error"}.each do |error, status|
    it "is a #{status} when a #{error} is given no code" do
      expect(error.new).to have_attributes(code: status.to_i, message: status)
    end

    it "can be raised as a #{error} with a message alone" do
      expect { raise error, "Stubbed" }.to raise_error(an_instance_of(error).and(having_attributes(code: status.to_i, message: "Stubbed")))
    end
  end

  it "has the reason of the code it's given, not of its class" do
    expect(Sferik::ClientError.new(code: 429)).to have_attributes(code: 429, message: "429 Too Many Requests")
  end

  it "has the code alone when the code it's given has no reason" do
    expect(described_class.new(code: 299).message).to eq("299")
  end

  it "leaves the headers and body it's given as they were" do
    headers = {"content-type" => "text/plain"}
    body = +"Details"
    described_class.new(code: 500, reason: "", headers:, body:)

    expect([headers, body]).to all(satisfy { |given| !given.frozen? })
  end

  describe "#error_code" do
    def coded(body, type: "application/json")
      described_class.new(code: 429, headers: {"content-type" => type}, body:).error_code
    end

    it "is the code a JSON body names" do
      expect(coded(%({"error":"one message a minute, please","code":"busy"}\n))).to eq("busy")
    end

    it "is the code a binary JSON body names, in UTF-8" do
      expect(coded('{"code":"café"}'.b)).to eq("café").and(have_attributes(encoding: Encoding::UTF_8))
    end

    it "is the code a JSON body in another charset names" do
      expect(coded('{"code":"busy"}'.encode(Encoding::UTF_16LE), type: "application/json; charset=utf-16le")).to eq("busy")
    end

    it "is the code of a binary body with bytes that aren't valid UTF-8, replaced" do
      expect(coded(%({"code":"bu\xFFsy"}).b)).to eq("bu�sy")
    end

    it "is the code of a body with bytes that aren't valid in its charset, replaced" do
      expect(coded(%({"code":"bu\xFFsy"}))).to eq("bu�sy")
    end

    {"names none" => '{"error":"Not Found"}', "names one that isn't a string" => '{"code":429}', "isn't an object" => '["busy"]',
     "isn't JSON" => "busy", "is empty" => ""}.each do |what, body|
      it "is nil when the body #{what}" do
        expect(coded(body)).to be_nil
      end
    end

    it "is nil when the body is in a charset that can't be read as text" do
      expect(coded(String.new('{"code":"busy"}', encoding: Encoding::UTF_7))).to be_nil
    end

    it "is nil for an error built with nothing" do
      expect(described_class.new.error_code).to be_nil
    end
  end

  describe "#retry_after" do
    it "is there for any HTTP error, as a 502 from write has one" do
      expect(Sferik::ServerError.new(code: 502, headers: {"retry-after" => "60"}).retry_after).to eq(60)
    end

    it "has the seconds its Retry-After header gives" do
      expect(described_class.new(headers: {"retry-after" => "120"}).retry_after).to eq(120)
    end

    it "reads the seconds as a decimal number, whatever zeros they start with" do
      expect(described_class.new(headers: {"retry-after" => "090"}).retry_after).to eq(90)
    end

    it "has no seconds to wait when the response doesn't say" do
      expect(described_class.new.retry_after).to be_nil
    end

    ["Wed, 07 Oct 2026 07:28:00 GMT", "120 seconds", "in 120", "-1", ""].each do |value|
      it "has no seconds to wait for a Retry-After of #{value.inspect}, which isn't a number of them" do
        expect(described_class.new(headers: {"retry-after" => value}).retry_after).to be_nil
      end
    end
  end
end
