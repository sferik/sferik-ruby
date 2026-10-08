# frozen_string_literal: true

RSpec.describe Sferik::API::SiteEndpoints do
  let(:client) { Sferik::Client.new }

  describe "#who" do
    it "returns who's reading the site" do
      stub_get("/who", "who.json")

      expect(client.who).to be_a(Sferik::Who).and(all(have_attributes(tty: /\Attys\d{3}\z/, page: String, login: Time, idle: Integer)))
    end

    it "returns each terminal" do
      session = {"tty" => "ttys001", "page" => "/talks", "login" => "2026-10-06T12:00:00Z", "idle" => 42}
      stub_request(:get, "https://sferik.net/who").with(headers: {"Accept" => "application/json"}).to_return(body: JSON.generate("users" => [session]))

      expect(client.who.first).to have_attributes(tty: "ttys001", page: "/talks", login: Time.utc(2026, 10, 6, 12), idle: 42)
    end
  end

  describe "#check_in" do
    def stub_check_in(query)
      stub_request(:post, "https://sferik.net/who").with(query:, headers: {"Accept" => "application/json"})
        .to_return(body: fixture("check_in.json"), headers: {"Content-Type" => "application/json; charset=utf-8"})
    end

    it "checks in a terminal on the home page, and returns it with who's reading the site" do
      stub_check_in("token" => "0123456789abcdef", "page" => "/")

      expect(client.check_in("0123456789abcdef")).to be_a(Sferik::Who).and(have_attributes(you: /\Attys\d{3}\z/, first: have_attributes(page: "/", login: Time)))
    end

    it "checks in a terminal on the page given" do
      stub_check_in("token" => "0123456789abcdef", "page" => "/talks")

      expect(client.check_in("0123456789abcdef", page: "/talks").you).to match(/\Attys\d{3}\z/)
    end

    it "escapes the token and the page" do
      request = stub_request(:post, "https://sferik.net/who?token=a%26b%3Dc&page=%2Ftalks%3Fx").to_return(body: "{}")
      client.check_in("a&b=c", page: "/talks?x")

      expect(request).to have_been_made
    end

    it "raises ArgumentError for a token that isn't a String, and sends nothing" do
      expect { client.check_in(nil) }.to raise_error(ArgumentError, "token must be String, not nil")
    end

    it "raises ArgumentError for a page that isn't a String, and sends nothing" do
      expect { client.check_in("0123456789abcdef", page: :talks) }.to raise_error(ArgumentError, "page must be String, not :talks")
    end

    it "raises ClientError for a token that isn't one, with what the server says" do
      stub_request(:post, "https://sferik.net/who").with(query: {"token" => "short", "page" => "/"})
        .to_return(status: 400, body: %({"error":"token and page are required","code":"bad_token"}\n), headers: {"Content-Type" => "application/json; charset=utf-8"})

      expect { client.check_in("short") }.to raise_error(an_instance_of(Sferik::ClientError).and(having_attributes(message: "token and page are required", error_code: "bad_token")))
    end
  end

  describe "#write" do
    let(:key) { "0f8fad5b-d9cb-469f-a165-70867728950e" }

    before { allow(Kernel).to receive(:sleep) }

    def stub_write(url = "https://sferik.net/write", status: 202, body: %({"message":"message sent to sferik"}\n), headers: {})
      stub_request(:post, url).to_return(status:, body:, headers: {"Content-Type" => "application/json; charset=utf-8", **headers})
    end

    # How many times a stubbed request has been made
    def times_made(request)
      WebMock::RequestRegistry.instance.times_executed(request.request_pattern)
    end

    it "sends the message as the body, and returns what the server says" do
      stub_write.with(body: "Hello from Ruby", headers: {"Accept" => "application/json", "Content-Type" => "text/plain; charset=utf-8"})

      expect(client.write("Hello from Ruby")).to eq("message sent to sferik")
    end

    it "names no terminal unless it's given one" do
      stub_write
      client.write("Hello")

      expect(a_request(:post, "https://sferik.net/write").with { |request| request.uri.query.to_s.empty? }).to have_been_made
    end

    it "asks for a URL with no query, not an empty one, unless it's given a terminal" do
      stub_write
      allow(Net::HTTP::Post).to receive(:new).and_call_original
      client.write("Hello")

      expect(Net::HTTP::Post).to have_received(:new).with(URI("https://sferik.net/write"), anything)
    end

    it "names the sender's terminal" do
      request = stub_write("https://sferik.net/write?tty=ttys001")
      client.write("Hello", tty: "ttys001")

      expect(request).to have_been_made
    end

    it "sends the message with the key it's given" do
      request = stub_write.with(headers: {"Idempotency-Key" => key})
      client.write("Hello", key:)

      expect(request).to have_been_made
    end

    it "sends each message with a random key of its own, unless it's given one" do
      keys = []
      stub_write.with { |request| keys << request.headers.fetch("Idempotency-Key") }
      2.times { client.write("Hello") }

      expect(keys).to all(match(/\A\h{8}(-\h{4}){3}-\h{12}\z/)).and(satisfy { |sent| sent.uniq.size.eql?(2) })
    end

    it "waits five seconds before sending it again, to give the first time to arrive" do
      stub_request(:post, "https://sferik.net/write").to_timeout.then.to_return(body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})
      client.write("Hello")

      expect(Kernel).to have_received(:sleep).with(5).once
    end

    it "doesn't wait when the answer comes" do
      stub_write
      client.write("Hello")

      expect(Kernel).not_to have_received(:sleep)
    end

    it "doesn't send a message again that the server couldn't be connected to for, since none was sent" do
      tries = 0
      allow(Net::HTTP).to receive(:start) { (tries += 1) && raise(SocketError, "getaddrinfo: nodename nor servname provided") }

      expect { client.write("Hello") }.to raise_error(an_instance_of(Sferik::NetworkError)).and(change { tries }.by(1))
    end

    it "sends the message once more, with the same key, when no answer comes" do
      request = stub_request(:post, "https://sferik.net/write").with(body: "Hello", headers: {"Idempotency-Key" => key})
        .to_timeout.then.to_return(body: %({"message":"message sent to sferik"}), headers: {"Content-Type" => "application/json"})

      expect([client.write("Hello", key:), times_made(request)]).to eq(["message sent to sferik", 2])
    end

    it "sends the message to the terminal's URL again too" do
      request = stub_request(:post, "https://sferik.net/write?tty=ttys001").to_timeout.then.to_return(body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})
      client.write("Hello", tty: "ttys001")

      expect(request).to have_been_made.twice
    end

    it "raises Unanswered when no answer comes twice, and doesn't send it a third time" do
      request = stub_request(:post, "https://sferik.net/write").to_timeout

      expect { client.write("Hello") }.to raise_error(Sferik::Unanswered).and(change { times_made(request) }.by(2))
    end

    # Stub the server to say a message is still being sent, and then whatever comes next
    def stub_sending(headers: {"Retry-After" => "7"})
      stub_write(status: 409, body: %({"error":"that message is still being sent; ask again in a moment","code":"sending"}), headers:)
    end

    it "asks after a message once more that the server says is still being sent, with the same key" do
      request = stub_sending.with(body: "Hello", headers: {"Idempotency-Key" => key}).then
        .to_return(status: 202, body: %({"message":"message sent to sferik"}), headers: {"Content-Type" => "application/json"})

      expect([client.write("Hello", key:), times_made(request)]).to eq(["message sent to sferik", 2])
    end

    it "waits as long as the server says before asking after a message that's still being sent" do
      stub_sending.then.to_return(status: 202, body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})
      client.write("Hello")

      expect(Kernel).to have_received(:sleep).with(7).once
    end

    it "waits five seconds when the server doesn't say how long" do
      stub_sending(headers: {}).then.to_return(status: 202, body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})
      client.write("Hello")

      expect(Kernel).to have_received(:sleep).with(5).once
    end

    it "asks after a message at its terminal's URL too" do
      request = stub_request(:post, "https://sferik.net/write?tty=ttys001")
        .to_return(status: 409, body: %({"code":"sending"}), headers: {"Content-Type" => "application/json"}).then
        .to_return(status: 202, body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})
      client.write("Hello", tty: "ttys001")

      expect(request).to have_been_made.twice
    end

    it "raises the 409 for a message that's still being sent when it's asked after, and doesn't ask a third time" do
      request = stub_sending

      expect { client.write("Hello") }.to raise_error(an_instance_of(Sferik::ClientError).and(having_attributes(code: 409, error_code: "sending")))
        .and(change { times_made(request) }.by(2))
    end

    it "asks after a message that got no answer, and then is still being sent" do
      request = stub_request(:post, "https://sferik.net/write").to_timeout.then
        .to_return(status: 409, body: %({"code":"sending"}), headers: {"Content-Type" => "application/json", "Retry-After" => "7"}).then
        .to_return(status: 202, body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})

      expect([client.write("Hello"), times_made(request)]).to eq(["sent", 3])
    end

    it "sends a message again that got no answer when it was asked after" do
      request = stub_sending.then.to_timeout.then.to_return(status: 202, body: %({"message":"sent"}), headers: {"Content-Type" => "application/json"})

      expect([client.write("Hello"), times_made(request)]).to eq(["sent", 3])
    end

    it "doesn't send a message again that the server turned away for anything else, like a 409 of another kind" do
      request = stub_write(status: 409, body: %({"error":"no","code":"conflict"}), headers: {"Retry-After" => "7"})

      expect { client.write("Hello") }.to raise_error(Sferik::ClientError).and(change { times_made(request) }.by(1))
    end

    it "doesn't send a message again that the server turned away" do
      request = stub_write(status: 503, body: %({"error":"sferik isn't taking messages here","code":"unavailable"}))

      expect { client.write("Hello") }.to raise_error(Sferik::ServerError).and(change { times_made(request) }.by(1))
    end

    it "raises ArgumentError for a terminal that isn't a String, and sends nothing" do
      expect { client.write("Hello", tty: false) }.to raise_error(ArgumentError, "tty must be String, not false")
    end

    it "raises ArgumentError for a message that isn't a String, and sends nothing" do
      expect { client.write(nil) }.to raise_error(ArgumentError, "body must be String, not nil")
    end

    it "raises ArgumentError for a key that isn't a String, and sends nothing" do
      expect { client.write("Hello", key: 1) }.to raise_error(ArgumentError, "key must be String, not 1")
    end

    {"{}" => "nil", '{"message":["sent"]}' => '["sent"]'}.each do |body, got|
      it "raises InvalidResponse for a response of #{body}, which has no message" do
        stub_write(body:)

        expect { client.write("Hello") }.to raise_error(Sferik::InvalidResponse, "Expected a message, got #{got}")
      end
    end

    it "raises InvalidResponse for a response that isn't JSON" do
      stub_write(body: "write: message sent to sferik\n")

      expect { client.write("Hello") }.to raise_error(Sferik::InvalidResponse, /\ACouldn't parse the response as JSON/)
    end

    {400 => [Sferik::ClientError, "nothing to send", "empty"], 413 => [Sferik::ClientError, "that's too long for write; try mail", "too_long"],
     429 => [Sferik::TooManyRequests, "one message a minute, please", "busy"],
     502 => [Sferik::ServerError, "the message didn't go through; try again later", "undelivered"],
     503 => [Sferik::ServerError, "sferik isn't taking messages here", "unavailable"]}.each do |status, (error, message, code)|
      it "raises #{error} for a #{status}, with what the server says and which error it is" do
        stub_write(status:, body: JSON.generate(error: message, code:))

        expect { client.write("Hello") }.to raise_error(an_instance_of(error).and(having_attributes(code: status, message:, error_code: code)))
      end
    end

    it "says how long to wait when the server does" do
      stub_write(status: 429, body: '{"error":"one message a minute, please","code":"busy"}', headers: {"Retry-After" => "60"})

      expect { client.write("Hello") }.to raise_error(an_instance_of(Sferik::TooManyRequests).and(having_attributes(retry_after: 60)))
    end
  end

  describe "#text" do
    it "returns a resource as terminal output" do
      stub_get("/whoami", "whoami.txt", accept: "text/plain")

      expect(client.text("/whoami")).to start_with("I've spent nearly two decades")
    end

    it "defaults to the home page" do
      stub_request(:get, "https://sferik.net/").with(headers: {"Accept" => "text/plain"}).to_return(body: "Erik Berlin\n")

      expect(client.text).to eq("Erik Berlin\n")
    end
  end

  describe "#deployment" do
    it "returns the commit that's deployed, when it was, and where to read it" do
      stub_get("/version", "version.json")
      saved = JSON.parse(fixture("version.json")) # whichever commit was deployed when the fixtures were saved

      expect(client.deployment).to be_a(Sferik::Deployment).and(have_attributes(commit: saved.fetch("commit").match(/\A\h{40}\z/).to_s,
        deployed: Time.iso8601(saved.fetch("deployed")), url: "https://github.com/sferik/sferik-web/commit/#{saved.fetch("commit")}"))
    end

    it "returns nil for each from a copy of the site that wasn't deployed" do
      stub_request(:get, "https://sferik.net/version").with(headers: {"Accept" => "application/json"})
        .to_return(body: %({"commit":null,"deployed":null,"url":null}\n))

      expect(client.deployment).to have_attributes(commit: nil, deployed: nil, url: nil)
    end
  end

  describe "#status" do
    it "returns when GitHub was last asked with the site's token, and when it answered" do
      stub_get("/status", "status.json")

      expect(client.status).to be_a(Sferik::Status).and(have_attributes(github: be_a(Sferik::Status::GitHub)
        .and(have_attributes(asked: Time.utc(2026, 10, 8, 21, 45, 7), answered: Time.utc(2026, 10, 8, 21, 45, 7), error: nil))))
    end

    it "returns what went wrong, and when GitHub last answered, from a site whose token has expired" do
      stub_request(:get, "https://sferik.net/status").with(headers: {"Accept" => "application/json"})
        .to_return(body: %({"github":{"asked":"2026-10-08T22:00:00Z","answered":"2026-10-08T21:45:07Z","error":"https://api.github.com/graphql: 401"}}\n))

      expect(client.status.github).to have_attributes(asked: Time.utc(2026, 10, 8, 22), answered: Time.utc(2026, 10, 8, 21, 45, 7),
        error: "https://api.github.com/graphql: 401")
    end

    it "returns when the site last loaded each live value" do
      stub_get("/status", "status.json")

      expect(client.status.loaded).to be_a(Sferik::Status::Loaded).and(have_attributes(gems: Time.utc(2026, 10, 8, 21, 45, 7),
        stars: Time.utc(2026, 10, 8, 21, 45, 7), contributions: Time.utc(2026, 10, 8, 21, 45, 7), push: Time.utc(2026, 10, 8, 21, 45, 8)))
    end

    it "returns nil for a value the site has never loaded" do
      stub_request(:get, "https://sferik.net/status").with(headers: {"Accept" => "application/json"})
        .to_return(body: %({"github":{"asked":null,"answered":null,"error":null},"loaded":{"gems":"2026-10-08T21:45:07Z","stars":null,"contributions":null,"push":null}}\n))

      expect(client.status.loaded).to have_attributes(gems: Time.utc(2026, 10, 8, 21, 45, 7), stars: nil, contributions: nil, push: nil)
    end

    it "returns nil for each from a copy of the site that has no token" do
      stub_request(:get, "https://sferik.net/status").with(headers: {"Accept" => "application/json"})
        .to_return(body: %({"github":{"asked":null,"answered":null,"error":null}}\n))

      expect(client.status.github).to have_attributes(asked: nil, answered: nil, error: nil)
    end
  end

  describe "#openapi" do
    it "returns the API's description" do
      stub_get("/openapi.json", "openapi.json")

      expect(client.openapi).to include("openapi" => "3.1.0")
    end

    it "returns it deep-frozen" do
      stub_get("/openapi.json", "openapi.json")
      document = client.openapi

      expect([document, document["paths"], document["paths"].keys.first, document["openapi"]]).to all(be_frozen)
    end
  end
end
