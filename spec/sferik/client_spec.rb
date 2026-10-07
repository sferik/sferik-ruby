# frozen_string_literal: true

RSpec.describe Sferik::Client do
  subject(:client) { described_class.new }

  describe "#initialize" do
    it "defaults to the global configuration" do
      Sferik.host = "http://localhost:3745"

      expect([client.host, client.user_agent, client.open_timeout, client.read_timeout, client.write_timeout, client.max_redirects]).to eq(["http://localhost:3745", Sferik.user_agent, 5, 10, 10, 10])
    end

    it "drops a trailing slash from the host" do
      expect(described_class.new(host: "http://localhost:3745/").host).to eq("http://localhost:3745")
    end

    it "is frozen" do
      expect(client).to be_frozen
    end

    it "raises ArgumentError for a host without a scheme" do
      expect { described_class.new(host: "localhost:3745") }.to raise_error(ArgumentError, 'host must be an http or https URL, not "localhost:3745"')
    end

    it "raises ArgumentError for a host with another scheme" do
      expect { described_class.new(host: "ftp://sferik.net") }.to raise_error(ArgumentError, 'host must be an http or https URL, not "ftp://sferik.net"')
    end

    it "raises ArgumentError for a host that is only a scheme" do
      expect { described_class.new(host: "https://") }.to raise_error(ArgumentError, 'host must be an http or https URL, not "https://"')
    end

    it "raises ArgumentError for a host that names no server" do
      expect { described_class.new(host: "http:sferik.net") }.to raise_error(ArgumentError, 'host must be an http or https URL, not "http:sferik.net"')
    end

    it "raises ArgumentError for a host that can't be a URL" do
      expect { described_class.new(host: "https://sferik net") }.to raise_error(ArgumentError, 'host must be an http or https URL, not "https://sferik net"')
    end

    it "raises ArgumentError for a host with credentials" do
      expect { described_class.new(host: "https://erik:secret@sferik.net") }.to raise_error(ArgumentError, 'host must have no credentials, query, or fragment, not "https://erik:secret@sferik.net"')
    end

    it "raises ArgumentError for a host with a query" do
      expect { described_class.new(host: "https://sferik.net?x=1") }.to raise_error(ArgumentError, 'host must have no credentials, query, or fragment, not "https://sferik.net?x=1"')
    end

    it "raises ArgumentError for a host with an empty query" do
      expect { described_class.new(host: "https://sferik.net?") }.to raise_error(ArgumentError, 'host must have no credentials, query, or fragment, not "https://sferik.net?"')
    end

    it "raises ArgumentError for a host with a fragment" do
      expect { described_class.new(host: "https://sferik.net#top") }.to raise_error(ArgumentError, 'host must have no credentials, query, or fragment, not "https://sferik.net#top"')
    end

    it "takes a host with a port and a path" do
      expect(described_class.new(host: "http://localhost:3745/api").host).to eq("http://localhost:3745/api")
    end

    it "has a frozen host and user agent" do
      expect([client.host, described_class.new(host: +"http://localhost:3745").host, client.user_agent]).to all(be_frozen)
    end

    it "freezes a copy of the user agent, not the one given" do
      user_agent = +"my-app/1.0"

      expect([described_class.new(user_agent:).user_agent, user_agent.frozen?]).to eq(["my-app/1.0", false])
    end

    ["my-app\n1.0", "my-app\r1.0"].each do |user_agent|
      it "raises ArgumentError for a user agent of #{user_agent.inspect}, which has a line break" do
        expect { described_class.new(user_agent:) }.to raise_error(ArgumentError, "user_agent must be on one line, not #{user_agent.inspect}")
      end
    end

    it "raises ArgumentError for a negative max_redirects" do
      expect { described_class.new(max_redirects: -1) }.to raise_error(ArgumentError, "max_redirects must be 0 or more, not -1")
    end

    it "takes a max_redirects of 0" do
      expect(described_class.new(max_redirects: 0).max_redirects).to eq(0)
    end

    {host: nil, user_agent: :ruby, open_timeout: "5", read_timeout: nil, write_timeout: :soon, max_redirects: 1.5}.each do |option, value|
      it "raises ArgumentError for a #{option} of the wrong type" do
        type = {host: String, user_agent: String, max_redirects: Integer}.fetch(option, Numeric)

        expect { described_class.new(option => value) }.to raise_error(ArgumentError, "#{option} must be #{type}, not #{value.inspect}")
      end
    end

    [[:open_timeout, 0], [:read_timeout, -1], [:open_timeout, -0.5], [:read_timeout, 0.0], [:open_timeout, Float::INFINITY],
      [:read_timeout, Float::NAN], [:open_timeout, Complex(1, 1)], [:write_timeout, 0]].each do |option, value|
      it "raises ArgumentError for a #{option} of #{value}" do
        expect { described_class.new(option => value) }.to raise_error(ArgumentError, "#{option} must be positive and finite, not #{value}")
      end
    end

    it "takes timeouts with fractions of a second" do
      expect(described_class.new(open_timeout: 0.5, read_timeout: 1.5, write_timeout: 2.5)).to have_attributes(open_timeout: 0.5, read_timeout: 1.5, write_timeout: 2.5)
    end
  end

  describe "#get" do
    describe "redirects" do
      def redirect(from, to, status: 301)
        stub_request(:get, from).to_return(status:, headers: to ? {"Location" => to} : {})
      end

      it "follows a redirect, keeping the media type asked for" do
        redirect("https://sferik.net/old", "/whoami")
        stub_get("/whoami", "whoami.txt", accept: "text/plain")

        expect(client.get("/old", accept: "text/plain")).to eq(fixture("whoami.txt"))
      end

      it "follows a redirect to another host" do
        redirect("https://sferik.net/whoami", "https://www.sferik.net/whoami", status: 308)
        stub_request(:get, "https://www.sferik.net/whoami").to_return(body: "ok")

        expect(client.get("/whoami")).to eq("ok")
      end

      it "follows a redirect from http to https" do
        redirect("http://localhost:3745/whoami", "https://sferik.net/whoami")
        stub_request(:get, "https://sferik.net/whoami").to_return(body: "ok")

        expect(described_class.new(host: "http://localhost:3745").get("/whoami")).to eq("ok")
      end

      it "follows a redirect from http to http" do
        redirect("http://localhost:3745/a", "/b")
        stub_request(:get, "http://localhost:3745/b").to_return(body: "ok")

        expect(described_class.new(host: "http://localhost:3745").get("/a")).to eq("ok")
      end

      it "treats a redirect from https to http as an error" do
        redirect("https://sferik.net/whoami", "http://sferik.net/whoami")

        expect { client.get("/whoami") }
          .to raise_error(an_instance_of(Sferik::HTTPError).and(having_attributes(code: 301, message: "Refused to follow a redirect from https://sferik.net/whoami to http://sferik.net/whoami")))
      end

      it "follows up to max_redirects of them" do
        redirect("https://sferik.net/a", "/b")
        redirect("https://sferik.net/b", "/c")
        stub_request(:get, "https://sferik.net/c").to_return(body: "ok")

        expect(described_class.new(max_redirects: 2).get("/a")).to eq("ok")
      end

      it "raises TooManyRedirects for one more than max_redirects" do
        redirect("https://sferik.net/a", "/b")
        redirect("https://sferik.net/b", "/c")

        expect { described_class.new(max_redirects: 1).get("/a") }.to raise_error(Sferik::TooManyRedirects, "More than 1 redirects (GET https://sferik.net/b)")
      end

      it "follows none when max_redirects is 0" do
        redirect("https://sferik.net/a", "/b")

        expect { described_class.new(max_redirects: 0).get("/a") }.to raise_error(Sferik::TooManyRedirects)
      end

      it "treats a redirect without a location as an error" do
        redirect("https://sferik.net/a", nil, status: 302)

        expect { client.get("/a") }.to raise_error(an_instance_of(Sferik::HTTPError).and(having_attributes(code: 302)))
      end

      it "treats a redirect to a URL that isn't http or https as an error" do
        redirect("https://sferik.net/a", "ftp://sferik.net/a")

        expect { client.get("/a") }
          .to raise_error(an_instance_of(Sferik::HTTPError).and(having_attributes(code: 301, message: "Refused to follow a redirect from https://sferik.net/a to ftp://sferik.net/a")))
      end

      it "treats a redirect to an invalid URL as an error" do
        redirect("https://sferik.net/a", "http://[invalid")

        expect { client.get("/a") }.to raise_error(an_instance_of(Sferik::HTTPError).and(having_attributes(code: 301)))
      end

      ["https:/b", "https:///b"].each do |location|
        it "treats a redirect to #{location}, which has no host, as an error" do
          redirect("https://sferik.net/a", location)

          expect { client.get("/a") }.to raise_error(an_instance_of(Sferik::HTTPError).and(having_attributes(code: 301, message: "301")))
        end
      end

      it "doesn't treat a location on a success as a redirect" do
        stub_request(:get, "https://sferik.net/a").to_return(status: 201, body: "created", headers: {"Location" => "/b"})

        expect(client.get("/a")).to eq("created")
      end
    end

    it "asks for the media type, with the user agent" do
      stub_get("/whoami", "whoami.txt", accept: "text/plain")
      client.get("/whoami", accept: "text/plain")

      expect(a_request(:get, "https://sferik.net/whoami").with(headers: {"User-Agent" => Sferik.user_agent})).to have_been_made
    end

    it "returns the body" do
      stub_get("/whoami", "whoami.txt", accept: "text/plain")

      expect(client.get("/whoami", accept: "text/plain")).to eq(fixture("whoami.txt"))
    end

    it "asks for JSON by default, and works without a leading slash" do
      stub_get("/whoami", "whoami.json")

      expect(client.get("whoami")).to eq(fixture("whoami.json"))
    end

    it "returns text in the charset the response names" do
      stub_get("/whoami", "whoami.txt", accept: "text/plain")

      expect(client.get("/whoami", accept: "text/plain").encoding).to eq(Encoding::UTF_8)
    end

    it "decodes a body the server sent as bytes" do
      stub_request(:get, "https://sferik.net/x").to_return(body: "caf\xC3\xA9".b, headers: {"Content-Type" => "text/plain; charset=utf-8"})

      expect(client.get("/x")).to eq("café")
    end

    it "returns a body in another charset the response names" do
      stub_request(:get, "https://sferik.net/x").to_return(body: "caf\xE9".b, headers: {"Content-Type" => "text/plain; charset=iso-8859-1"})

      expect(client.get("/x")).to eq("café".encode(Encoding::ISO_8859_1))
    end

    it "returns a binary body when the response names no charset" do
      stub_request(:get, "https://sferik.net/x").to_return(body: "%PDF-1.4\n", headers: {"Content-Type" => "application/pdf"})

      expect(client.get("/x")).to eq("%PDF-1.4\n".b).and(have_attributes(encoding: Encoding::BINARY))
    end

    it "returns a binary body when the response has no Content-Type" do
      stub_request(:get, "https://sferik.net/x").to_return(body: "ok")

      expect(client.get("/x").encoding).to eq(Encoding::BINARY)
    end

    {
      'text/plain; charset="utf-8"' => "in quotes",
      "text/plain; Charset=UTF-8" => "in any case",
      "text/plain;charset=utf-8" => "without a space before it",
      "text/plain;\tcharset=utf-8" => "after a tab",
      "text/plain; format=flowed; charset=utf-8; delsp=yes" => "among other parameters",
      "text/plain; charset=utf-8 " => "before a space"
    }.each do |type, how|
      it "returns text in a charset the response names #{how}" do
        stub_request(:get, "https://sferik.net/x").to_return(body: "café".b, headers: {"Content-Type" => type})

        expect(client.get("/x")).to eq("café").and(have_attributes(encoding: Encoding::UTF_8))
      end
    end

    [
      "text/plain", "Text/HTML", "application/json", "APPLICATION/JSON; indent=2", "text/plain; charset", "text/plain; charset=", 'text/plain; charset=""',
      "text/plain; xcharset=utf-8", "text/plain charset=utf-8", "text/plain; charset =utf-8"
    ].each do |type|
      it "returns text in UTF-8 for a Content-Type of #{type.inspect}, which is text or JSON and names no charset" do
        stub_request(:get, "https://sferik.net/x").to_return(body: "naïve".b, headers: {"Content-Type" => type})

        expect(client.get("/x")).to eq("naïve").and(have_attributes(encoding: Encoding::UTF_8))
      end
    end

    ["application/pdf; charset", "application/pdf; note=text/plain", "application/x-text/plain", "application/jsonl", "application/x-application/json", "context/plain"].each do |type|
      it "returns a binary body for a Content-Type of #{type.inspect}, which is neither text nor JSON and names no charset" do
        stub_request(:get, "https://sferik.net/x").to_return(body: "ok", headers: {"Content-Type" => type})

        expect(client.get("/x").encoding).to eq(Encoding::BINARY)
      end
    end

    it "returns a binary body when the response names a charset Ruby doesn't know" do
      stub_request(:get, "https://sferik.net/x").to_return(body: "ok", headers: {"Content-Type" => "text/plain; charset=klingon"})

      expect(client.get("/x")).to eq("ok").and(have_attributes(encoding: Encoding::BINARY))
    end

    it "returns a binary body when the response names a charset that is no encoding" do
      stub_request(:get, "https://sferik.net/x").to_return(body: "ok", headers: {"Content-Type" => "text/plain; charset=internal"})

      expect(client.get("/x").encoding).to eq(Encoding::BINARY)
    end

    it "returns an empty body when the response has none" do
      stub_request(:get, "https://sferik.net/x").to_return(status: 204)

      expect(client.get("/x")).to eq("")
    end

    it "leaves the body of the response as it was" do
      body = "ok"
      stub_request(:get, "https://sferik.net/x").to_return(body:, headers: {"Content-Type" => "text/plain; charset=utf-16le"})
      client.get("/x")

      expect(body.encoding).to eq(Encoding::UTF_8)
    end

    it "keeps a path that looks like a URL on the host" do
      stub_request(:get, "https://sferik.net/http://example.com/").to_return(body: "ok")

      expect(client.get("http://example.com/")).to eq("ok")
    end

    ["text/plain\nX-Other: 1", "text/plain\rX-Other: 1"].each do |accept|
      it "raises ArgumentError for a media type of #{accept.inspect}, which has a line break" do
        expect { client.get("/whoami", accept:) }.to raise_error(ArgumentError, "accept must be on one line, not #{accept.inspect}")
      end
    end

    it "raises ArgumentError for a path that isn't a String" do
      expect { client.get(:whoami) }.to raise_error(ArgumentError, "path must be String, not :whoami")
    end

    [:json, nil].each do |accept|
      it "raises ArgumentError for a media type of #{accept.inspect}, which isn't a String" do
        expect { client.get("/whoami", accept:) }.to raise_error(ArgumentError, "accept must be String, not #{accept.inspect}")
      end
    end

    it "raises InvalidURL for a path that can't be in a URL" do
      expect { client.get("/a b") }.to raise_error(Sferik::InvalidURL, '"https://sferik.net/a b" isn\'t a valid URL')
    end

    it "keeps a path the host has" do
      stub_request(:get, "http://localhost:3745/api/whoami").to_return(body: "ok")

      expect(described_class.new(host: "http://localhost:3745/api").get("/whoami")).to eq("ok")
    end

    it "uses the timeouts" do
      stub_get("/whoami", "whoami.json")
      allow(Net::HTTP).to receive(:start).and_call_original
      described_class.new(open_timeout: 1, read_timeout: 2, write_timeout: 3).get("/whoami")

      expect(Net::HTTP).to have_received(:start).with("sferik.net", 443, use_ssl: true, open_timeout: 1, read_timeout: 2, write_timeout: 3)
    end

    it "connects to an IPv6 host by its address, without the brackets a URL puts around it" do
      stub_request(:get, "http://[::1]:3745/whoami").to_return(body: "ok")
      allow(Net::HTTP).to receive(:start).and_call_original
      described_class.new(host: "http://[::1]:3745").get("/whoami")

      expect(Net::HTTP).to have_received(:start).with("::1", 3745, use_ssl: false, open_timeout: 5, read_timeout: 10, write_timeout: 10)
    end

    it "uses plain HTTP for an http host" do
      stub_request(:get, "http://localhost:3745/whoami").to_return(body: "ok")

      expect(described_class.new(host: "http://localhost:3745").get("/whoami")).to eq("ok")
    end

    {404 => Sferik::NotFound, 406 => Sferik::NotAcceptable, 429 => Sferik::TooManyRequests, 418 => Sferik::ClientError, 503 => Sferik::ServerError, 304 => Sferik::HTTPError}.each do |status, error|
      it "raises #{error} for a #{status}, with the body as the message" do
        stub_request(:get, "https://sferik.net/x").to_return(status: [status, "Status"], body: "Details\n", headers: {"Content-Type" => "text/plain; charset=utf-8"})

        expect { client.get("/x") }.to raise_error(an_instance_of(error).and(having_attributes(code: status, message: "Details")))
      end
    end

    it "uses the error a JSON body names as the message" do
      stub_request(:get, "https://sferik.net/nope").to_return(status: 404, body: '{"error":"Not Found","path":"/nope"}')

      expect { client.get("/nope") }.to raise_error(Sferik::NotFound, "Not Found")
    end

    it "uses the status line as the message, not a page of HTML" do
      stub_request(:get, "https://sferik.net/x").to_return(status: [502, "Bad Gateway"], body: "<html></html>", headers: {"Content-Type" => "text/html"})

      expect { client.get("/x") }.to raise_error(Sferik::ServerError, "502 Bad Gateway")
    end

    it "keeps the status code, headers, and body of the response on the error" do
      stub_request(:get, "https://sferik.net/x").to_return(status: 404, body: "caf\xC3\xA9".b, headers: {"Content-Type" => "text/html; charset=utf-8", "X-Trace" => "1"})

      expect { client.get("/x") }.to raise_error(having_attributes(code: 404, headers: {"content-type" => "text/html; charset=utf-8", "x-trace" => "1"}, body: "café"))
    end

    it "uses the status line as the message when the body is empty" do
      stub_request(:get, "https://sferik.net/x").to_return(status: [500, "Internal Server Error"], body: "")

      expect { client.get("/x") }.to raise_error(Sferik::ServerError, "500 Internal Server Error")
    end

    it "raises NetworkError when the server times out" do
      stub_request(:get, "https://sferik.net/x").to_timeout

      expect { client.get("/x") }.to raise_error(Sferik::NetworkError, %r{\ANet::OpenTimeout: .* \(GET https://sferik.net/x\)\z})
    end

    it "raises NetworkError when the body doesn't decompress" do
      stub_request(:get, "https://sferik.net/x").to_raise(Zlib::DataError.new("incorrect header check"))

      expect { client.get("/x") }.to raise_error(Sferik::NetworkError, "Zlib::DataError: incorrect header check (GET https://sferik.net/x)")
    end

    it "raises NetworkError when a header of the response is malformed" do
      stub_request(:get, "https://sferik.net/x").to_raise(Net::HTTPHeaderSyntaxError.new("wrong header line format"))

      expect { client.get("/x") }.to raise_error(Sferik::NetworkError, "Net::HTTPHeaderSyntaxError: wrong header line format (GET https://sferik.net/x)")
    end

    it "raises NetworkError when the server breaks the protocol" do
      stub_request(:get, "https://sferik.net/x").to_raise(Net::ProtocolError.new("unexpected response"))

      expect { client.get("/x") }.to raise_error(Sferik::NetworkError, "Net::ProtocolError: unexpected response (GET https://sferik.net/x)")
    end

    it "raises Unanswered, which is a NetworkError, when the request was sent and no answer came" do
      stub_request(:get, "https://sferik.net/x").to_timeout

      expect { client.get("/x") }.to raise_error(an_instance_of(Sferik::Unanswered).and(be_a(Sferik::NetworkError)))
    end

    it "raises NetworkError, and not Unanswered, when the server couldn't be connected to, so nothing was sent" do
      allow(Net::HTTP).to receive(:start).and_raise(SocketError, "getaddrinfo: nodename nor servname provided")

      expect { client.get("/x") }.to raise_error(an_instance_of(Sferik::NetworkError), "SocketError: getaddrinfo: nodename nor servname provided (GET https://sferik.net/x)")
    end

    it "raises NetworkError, and not Unanswered, when a connection to keep couldn't be opened" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout, "execution expired")

      expect { client.keep_alive { |kept| kept.get("/x") } }.to raise_error(an_instance_of(Sferik::NetworkError), "Net::OpenTimeout: execution expired (GET https://sferik.net/x)")
    end

    it "raises NetworkError when the connection is refused" do
      stub_request(:get, "https://sferik.net/x").to_raise(Errno::ECONNREFUSED)

      # The operating system words the message: "Connection refused" on Linux and macOS, otherwise on Windows
      expect { client.get("/x") }.to raise_error(Sferik::NetworkError, /\AErrno::ECONNREFUSED: #{Regexp.escape(Errno::ECONNREFUSED.new.message)}/)
    end
  end

  describe "#post" do
    it "sends the body as plain text, asking for the media type, with the user agent" do
      request = stub_request(:post, "https://sferik.net/write")
        .with(body: "Hello", headers: {"Accept" => "text/plain", "Content-Type" => "text/plain; charset=utf-8", "User-Agent" => Sferik.user_agent})
        .to_return(status: 202, body: "sent\n")
      client.post("/write", "Hello", accept: "text/plain")

      expect(request).to have_been_made
    end

    it "sends an idempotency key it's given" do
      request = stub_request(:post, "https://sferik.net/write").with(headers: {"Idempotency-Key" => "0123456789abcdef"}).to_return(body: "sent")
      client.post("/write", "Hello", idempotency_key: "0123456789abcdef")

      expect(request).to have_been_made
    end

    it "sends no idempotency key unless it's given one" do
      stub_request(:post, "https://sferik.net/write").to_return(body: "sent")
      allow(Net::HTTP::Post).to receive(:new).and_call_original
      client.post("/write", "Hello", accept: "text/plain")

      expect(Net::HTTP::Post).to have_received(:new).with(anything, {"Accept" => "text/plain", "User-Agent" => Sferik.user_agent, "Content-Type" => "text/plain; charset=utf-8"})
    end

    it "raises ArgumentError for an idempotency key that isn't a String, and sends nothing" do
      expect { client.post("/write", "Hello", idempotency_key: 1) }.to raise_error(ArgumentError, "idempotency_key must be String, not 1")
    end

    it "raises ArgumentError for an idempotency key with a line break, and sends nothing" do
      expect { client.post("/write", "Hello", idempotency_key: "a\nb") }.to raise_error(ArgumentError, 'idempotency_key must be on one line, not "a\nb"')
    end

    it "returns the body, in the charset the response names" do
      stub_request(:post, "https://sferik.net/write").to_return(body: "café".b, headers: {"Content-Type" => "text/plain; charset=utf-8"})

      expect(client.post("/write", "Hello")).to eq("café")
    end

    it "asks for JSON and sends an empty body by default, and works without a leading slash" do
      stub_request(:post, "https://sferik.net/who").with(body: "", headers: {"Accept" => "application/json"}).to_return(body: "{}")

      expect(client.post("who")).to eq("{}")
    end

    {
      "converts a body in another charset to UTF-8" => ["caf\xE9".dup.force_encoding(Encoding::ISO_8859_1), "café"],
      "sends a binary body as it is, taking it for UTF-8" => ["caf\xC3\xA9".b, "café"],
      "sends a binary body that isn't UTF-8 as it is too" => ["caf\xE9".b, "caf\xE9"],
      "sends a US-ASCII body as it is, taking it for UTF-8" => ["caf\xC3\xA9".dup.force_encoding(Encoding::US_ASCII), "café"],
      "replaces bytes that aren't valid in the body's charset" => ["caf\xFF".dup.force_encoding(Encoding::EUC_JP), "caf\uFFFD"],
      "replaces a character UTF-8 doesn't have" => ["caf\x81".dup.force_encoding(Encoding::Windows_1252), "caf\uFFFD"]
    }.each do |what, (body, sent)|
      it what do
        stub_request(:post, "https://sferik.net/write").to_return(body: "sent")
        client.post("/write", body)

        expect(a_request(:post, "https://sferik.net/write").with { |request| request.body.b.eql?(sent.b) }).to have_been_made
      end
    end

    it "raises ArgumentError for a body in a charset that doesn't convert to UTF-8, and sends nothing" do
      body = "Hello".dup.force_encoding(Encoding::UTF_7)

      expect { client.post("/write", body) }.to raise_error(ArgumentError, "body must be in a charset that converts to UTF-8, not UTF-7")
    end

    it "keeps the query of the path" do
      stub_request(:post, "https://sferik.net/who?token=abc&page=/").to_return(body: "{}")

      expect(client.post("/who?token=abc&page=/")).to eq("{}")
    end

    it "uses the timeouts" do
      stub_request(:post, "https://sferik.net/write").to_return(body: "sent")
      allow(Net::HTTP).to receive(:start).and_call_original
      described_class.new(open_timeout: 1, read_timeout: 2, write_timeout: 3).post("/write", "Hello")

      expect(Net::HTTP).to have_received(:start).with("sferik.net", 443, use_ssl: true, open_timeout: 1, read_timeout: 2, write_timeout: 3)
    end

    it "doesn't follow a redirect, which is an error" do
      stub_request(:post, "https://sferik.net/write").to_return(status: [301, "Moved Permanently"], headers: {"Location" => "/written"})

      expect { client.post("/write", "Hello") }.to raise_error(an_instance_of(Sferik::HTTPError).and(having_attributes(code: 301, message: "301 Moved Permanently")))
    end

    {404 => Sferik::NotFound, 429 => Sferik::TooManyRequests, 418 => Sferik::ClientError, 503 => Sferik::ServerError}.each do |status, error|
      it "raises #{error} for a #{status}, with the body as the message" do
        stub_request(:post, "https://sferik.net/write").to_return(status:, body: "Details\n", headers: {"Content-Type" => "text/plain; charset=utf-8"})

        expect { client.post("/write", "Hello") }.to raise_error(an_instance_of(error).and(having_attributes(code: status, message: "Details")))
      end
    end

    it "raises NetworkError when the server times out, naming the request" do
      stub_request(:post, "https://sferik.net/write").to_timeout

      expect { client.post("/write", "Hello") }.to raise_error(Sferik::NetworkError, %r{\ANet::OpenTimeout: .* \(POST https://sferik.net/write\)\z})
    end

    it "raises InvalidURL for a path that can't be in a URL" do
      expect { client.post("/a b") }.to raise_error(Sferik::InvalidURL, '"https://sferik.net/a b" isn\'t a valid URL')
    end

    it "raises ArgumentError for a path that isn't a String" do
      expect { client.post(:write) }.to raise_error(ArgumentError, "path must be String, not :write")
    end

    it "raises ArgumentError for a body that isn't a String" do
      expect { client.post("/write", nil) }.to raise_error(ArgumentError, "body must be String, not nil")
    end

    it "raises ArgumentError for a media type that isn't a String" do
      expect { client.post("/write", accept: nil) }.to raise_error(ArgumentError, "accept must be String, not nil")
    end

    it "raises ArgumentError for a media type with a line break" do
      expect { client.post("/write", accept: "text/plain\r\nX: y") }.to raise_error(ArgumentError, 'accept must be on one line, not "text/plain\r\nX: y"')
    end
  end

  describe "#keep_alive" do
    # Every connection opened, and how: with a block, which closes it, or without one, which leaves it open
    let(:opened) { [] }

    before do
      allow(Net::HTTP).to receive(:start).and_wrap_original do |start, *args, **options, &block|
        opened << [block ? :closed : :kept, args.first, args.last, options.fetch(:use_ssl)]
        start.call(*args, **options, &block).tap { |http| opened.last << http unless block }
      end
      stub_request(:get, "https://sferik.net/whoami").to_return(body: "one")
      stub_request(:get, "https://sferik.net/talks").to_return(body: "two")
    end

    it "makes every request to a host over one connection, left open between them" do
      stub_request(:post, "https://sferik.net/write").to_return(body: "three")
      bodies = client.keep_alive { |kept| [kept.get("/whoami"), kept.get("/talks"), kept.post("/write", "Hello")] }

      expect([bodies, opened.map { |connection| connection.first(4) }]).to eq([%w[one two three], [[:kept, "sferik.net", 443, true]]])
    end

    it "closes its connections when the block ends" do
      started = client.keep_alive { |kept| kept.get("/whoami") && opened.last.last.started? }

      expect([started, opened.last.last.started?]).to eq([true, false])
    end

    it "closes its connections when the block raises, and raises what it did" do
      failing = -> { client.keep_alive { |kept| kept.get("/whoami") && raise("stop") } }

      expect(&failing).to raise_error(RuntimeError, "stop").and(change { opened.last&.last&.started? }.from(nil).to(false))
    end

    [
      ["port", "http://localhost:3746/whoami", [[:kept, "localhost", 3745, false], [:kept, "localhost", 3746, false]]],
      ["host", "http://127.0.0.1:3745/whoami", [[:kept, "localhost", 3745, false], [:kept, "127.0.0.1", 3745, false]]],
      ["scheme", "https://localhost:3745/whoami", [[:kept, "localhost", 3745, false], [:kept, "localhost", 3745, true]]]
    ].each do |part, elsewhere, connections|
      it "keeps a connection of its own for another #{part}, as a redirect may lead to" do
        stub_request(:get, "http://localhost:3745/whoami").to_return(status: 302, headers: {"Location" => elsewhere})
        stub_request(:get, elsewhere).to_return(body: "ok")
        described_class.new(host: "http://localhost:3745").keep_alive { |kept| 2.times { kept.get("/whoami") } }

        expect(opened.map { |connection| connection.first(4) }).to eq(connections)
      end
    end

    it "yields a client with the same options, frozen" do
      options = {host: "http://localhost:3745", user_agent: "agent", open_timeout: 1, read_timeout: 2, write_timeout: 3, max_redirects: 4}

      expect(described_class.new(**options).keep_alive(&:itself)).to be_an_instance_of(described_class).and(be_frozen).and(have_attributes(**options))
    end

    it "uses the timeouts of the client it's called on" do
      described_class.new(open_timeout: 1, read_timeout: 2, write_timeout: 3).keep_alive { |kept| kept.get("/whoami") }

      expect(Net::HTTP).to have_received(:start).with("sferik.net", 443, use_ssl: true, open_timeout: 1, read_timeout: 2, write_timeout: 3)
    end

    it "leaves the client it's called on opening a connection for each request" do
      client.keep_alive { |kept| kept.get("/whoami") }
      client.get("/whoami")

      expect(opened.map(&:first)).to eq(%i[kept closed])
    end

    it "returns what the block returns" do
      expect(client.keep_alive { :done }).to eq(:done)
    end

    it "opens no connection until a request is made" do
      client.keep_alive { nil }

      expect(opened).to eq([])
    end

    it "raises NetworkError for a request that fails, as outside the block" do
      stub_request(:get, "https://sferik.net/whoami").to_timeout

      expect { client.keep_alive { |kept| kept.get("/whoami") } }.to raise_error(Sferik::NetworkError, /\(GET https:\/\/sferik\.net\/whoami\)\z/)
    end

    it "raises ArgumentError without a block" do
      expect { client.keep_alive }.to raise_error(ArgumentError, "keep_alive must be given a block")
    end

    it "keeps the method that sets where connections are kept to itself" do
      expect { client.keep({}) }.to raise_error(NoMethodError, /protected method 'keep' called/)
    end
  end

  describe "#cached" do
    let(:options) { {host: "http://localhost:3745", user_agent: "agent", open_timeout: 1, read_timeout: 2, write_timeout: 3, max_redirects: 4} }

    before { stub_request(:get, "https://sferik.net/whoami").to_return(body: "ok", headers: {"ETag" => '"v1"', "Cache-Control" => "public, max-age=60"}) }

    it "returns a client with the same options, frozen" do
      expect(described_class.new(**options).cached).to be_an_instance_of(described_class).and(be_frozen).and(have_attributes(**options))
    end

    it "returns a client that asks once for what it gets twice while it's good" do
      cached = client.cached
      bodies = Array.new(2) { cached.get("/whoami") }

      expect([bodies, WebMock::RequestRegistry.instance.times_executed(a_request(:get, "https://sferik.net/whoami"))]).to eq([%w[ok ok], 1])
    end

    it "leaves the client it's called on asking each time" do
      client.cached.get("/whoami")
      2.times { client.get("/whoami") }

      expect(a_request(:get, "https://sferik.net/whoami")).to have_been_made.times(3)
    end

    it "returns a client with a cache of its own each time" do
      2.times { client.cached.get("/whoami") }

      expect(a_request(:get, "https://sferik.net/whoami")).to have_been_made.twice
    end

    it "returns a client that uses the timeouts of the one it's called on" do
      allow(Net::HTTP).to receive(:start).and_call_original
      described_class.new(open_timeout: 1, read_timeout: 2, write_timeout: 3).cached.get("/whoami")

      expect(Net::HTTP).to have_received(:start).with("sferik.net", 443, use_ssl: true, open_timeout: 1, read_timeout: 2, write_timeout: 3)
    end

    it "returns a client that keeps what it gets in keep_alive too, over one connection" do
      allow(Net::HTTP).to receive(:start).and_call_original
      cached = client.cached
      cached.keep_alive { |kept| 2.times { kept.get("/whoami") } }

      expect([cached.get("/whoami"), WebMock::RequestRegistry.instance.times_executed(a_request(:get, "https://sferik.net/whoami"))]).to eq(["ok", 1])
    end

    it "can be asked of a client in keep_alive, which then keeps what it gets over the connection kept open" do
      allow(Net::HTTP).to receive(:start).and_call_original
      stub_request(:get, "https://sferik.net/talks").to_return(body: "talks")
      client.keep_alive { |kept| kept.cached.then { |cached| [cached.get("/whoami"), cached.get("/talks")] } }

      expect(Net::HTTP).to have_received(:start).once
    end
  end

  describe "#inspect" do
    it "shows the host" do
      expect(client.inspect).to eq("#<Sferik::Client https://sferik.net>")
    end
  end
end
