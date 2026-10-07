# frozen_string_literal: true

RSpec.describe "Sferik::Cache" do
  # The time on the cache's clock, which a test moves forward
  let(:now) { [100.0] }
  let(:lock) { Mutex.new }
  let(:connections) { Sferik.const_get(:Connections).new({open_timeout: 5, read_timeout: 10, write_timeout: 10}) }
  let(:entries) { {} }
  let(:cache) { Sferik.const_get(:Cache).new(connections, -> { now.first }, entries, lock) }

  # The URL the examples ask for
  def url = "https://sferik.net/whoami"

  # Ask the cache for a URL as a media type, and return the response
  def get(url, accept = "application/json", through: cache)
    through.request(Net::HTTP::Get.new(URI(url), {"Accept" => accept}))
  end

  # Stub a URL to answer 200 with a body, an ETag, and a Cache-Control
  def stub_fresh(body: "one", etag: '"v1"', control: "public, max-age=60", url: self.url)
    stub_request(:get, url).to_return(body:, headers: {"ETag" => etag, "Cache-Control" => control}.compact)
  end

  # How many times a stubbed request has been made
  def made(request)
    WebMock::RequestRegistry.instance.times_executed(request.request_pattern)
  end

  # Move the clock forward
  def wait(seconds)
    now[0] += seconds
  end

  describe "#request" do
    it "answers with the response it kept for as long as the response said it's good for, without a request" do
      request = stub_fresh
      bodies = [get(url).body, wait(59.9) && get(url).body]

      expect([bodies, made(request)]).to eq([%w[one one], 1])
    end

    it "answers with the response itself, not a copy" do
      stub_fresh
      first = get(url)

      expect(get(url)).to be(first)
    end

    it "asks again once the response is no longer good, to the second" do
      request = stub_fresh
      get(url)
      wait(60)
      get(url)

      expect(request).to have_been_made.twice
    end

    it "asks with the ETag of the response it kept, and no ETag the first time" do
      stub_fresh
      get(url)
      wait(60)
      get(url)

      expect(a_request(:get, url).with { |request| request.headers["If-None-Match"].eql?('"v1"') }).to have_been_made.once
    end

    it "answers with the response it kept when the server says it hasn't changed" do
      stub_fresh.then.to_return(status: 304, headers: {"ETag" => '"v1"', "Cache-Control" => "public, max-age=60"})
      first = get(url)
      wait(60)

      expect(get(url)).to be(first).and(have_attributes(code: "200", body: "one"))
    end

    it "keeps a response that hasn't changed for as long as the server then says it's good for" do
      request = stub_fresh.then.to_return(status: 304, headers: {"Cache-Control" => "public, max-age=30"})
      get(url)
      wait(60)
      3.times { get(url) && wait(10) }

      expect(request).to have_been_made.times(2)
    end

    it "asks again each time for a response that hasn't changed, when the server doesn't say how long it's good for" do
      request = stub_fresh.then.to_return(status: 304)
      get(url)
      wait(60)
      2.times { get(url) }

      expect(request).to have_been_made.times(3)
    end

    it "keeps a response for as long as it's good for, less how long it says it has been kept already" do
      request = stub_request(:get, url).to_return(body: "one", headers: {"Cache-Control" => "public, max-age=60", "Age" => "55"})
      get(url)
      [4.9, 0.1].each { |seconds| wait(seconds) && get(url) }

      expect(request).to have_been_made.twice
    end

    it "takes the whole seconds of how long a response says it has been kept" do
      request = stub_request(:get, url).to_return(body: "one", headers: {"Cache-Control" => "public, max-age=60", "Age" => "58.9"})
      get(url)
      [1.9, 0.1].each { |seconds| wait(seconds) && get(url) }

      expect(request).to have_been_made.twice
    end

    it "asks again for a response that says it has been kept for as long as it's good for, or longer" do
      request = stub_request(:get, url).to_return(body: "one", headers: {"Cache-Control" => "public, max-age=60", "Age" => "75"})
      2.times { get(url) }

      expect(request).to have_been_made.twice
    end

    it "keeps a response that hasn't changed for as long as the server then says, less how long that answer has been kept" do
      request = stub_fresh.then.to_return(status: 304, headers: {"Cache-Control" => "public, max-age=30", "Age" => "25"})
      get(url)
      wait(60)
      [0, 4.9, 0.1].each { |seconds| wait(seconds) && get(url) }

      expect(request).to have_been_made.times(3)
    end

    it "answers with a response that has changed, and keeps that one" do
      request = stub_fresh.then.to_return(body: "two", headers: {"ETag" => '"v2"', "Cache-Control" => "public, max-age=60"})
      get(url)
      wait(60)

      expect([get(url).body, get(url).body, made(request)]).to eq(["two", "two", 2])
    end

    it "asks with the ETag of the latest response it kept" do
      stub_fresh.then.to_return(body: "two", headers: {"ETag" => '"v2"'})
      get(url)
      wait(60)
      2.times { get(url) }

      expect(a_request(:get, url).with(headers: {"If-None-Match" => '"v2"'})).to have_been_made.once
    end

    it "asks each time for a response that doesn't say how long it's good for, with its ETag" do
      stub_fresh(control: nil)
      2.times { get(url) }

      expect(a_request(:get, url).with(headers: {"If-None-Match" => '"v1"'})).to have_been_made.once
    end

    it "asks each time for a response that says to check each time, however long it says it's good for" do
      request = stub_fresh(control: "No-Cache, max-age=60")
      2.times { get(url) }

      expect(request).to have_been_made.twice
    end

    it "takes a longer word that ends in no-cache for no such thing" do
      request = stub_fresh(control: "xno-cache, max-age=60")
      2.times { get(url) }

      expect(request).to have_been_made.once
    end

    it "takes a longer word that starts with no-cache for no such thing" do
      request = stub_fresh(control: "no-cachex, max-age=60")
      2.times { get(url) }

      expect(request).to have_been_made.once
    end

    it "reads how long a response is good for whatever the case, and among other things" do
      request = stub_fresh(control: "public, Max-Age=60, stale-while-revalidate=5")
      2.times { get(url) }

      expect(request).to have_been_made.once
    end

    it "takes s-maxage, which is for a cache that's shared, for nothing" do
      request = stub_fresh(control: "s-maxage=60")
      2.times { get(url) }

      expect(request).to have_been_made.twice
    end

    it "takes a longer word that ends in max-age for nothing" do
      request = stub_fresh(control: "xmax-age=60")
      2.times { get(url) }

      expect(request).to have_been_made.twice
    end

    it "doesn't keep a response that says not to, whatever the case" do
      stub_fresh(control: "No-Store, max-age=60")
      2.times { get(url) }

      expect(a_request(:get, url).with { |request| !request.headers.key?("If-None-Match") }).to have_been_made.twice
    end

    it "takes a longer word that ends in no-store for no such thing" do
      request = stub_fresh(control: "xno-store, max-age=60")
      2.times { get(url) }

      expect(request).to have_been_made.once
    end

    it "takes a longer word that starts with no-store for no such thing" do
      request = stub_fresh(control: "no-storex, max-age=60")
      2.times { get(url) }

      expect(request).to have_been_made.once
    end

    it "forgets the response it kept when the server says not to keep the one that hasn't changed" do
      stub_fresh.then.to_return(status: 304, headers: {"Cache-Control" => "no-store"}).then.to_return(body: "two")
      get(url)
      wait(60)

      expect([get(url).body, get(url).body]).to eq(%w[one two])
    end

    it "keeps a response without an ETag for as long as it's good for, and then asks without one" do
      stub_fresh(etag: nil)
      get(url)
      wait(60)
      get(url)

      expect(a_request(:get, url).with { |request| !request.headers.key?("If-None-Match") }).to have_been_made.twice
    end

    it "doesn't keep a response that isn't a 200, and answers with it" do
      request = stub_request(:get, url).to_return(status: 404, body: "no", headers: {"ETag" => '"v1"', "Cache-Control" => "public, max-age=60"})

      expect([get(url).code, get(url).body, made(request)]).to eq(["404", "no", 2])
    end

    it "doesn't keep another success, like a 203, either" do
      request = stub_request(:get, url).to_return(status: 203, body: "ok", headers: {"Cache-Control" => "public, max-age=60"})
      2.times { get(url) }

      expect(request).to have_been_made.twice
    end

    it "forgets the response it kept when the server answers with one that isn't a 200, and answers with that" do
      stub_fresh.then.to_return(status: 500, body: "down").then.to_return(body: "two")
      get(url)
      wait(60)

      expect([get(url).body, get(url).body]).to eq(%w[down two])
    end

    it "keeps nothing once the server answers with a response that isn't a 200" do
      stub_fresh.then.to_return(status: 500, body: "down")
      get(url)
      wait(60)

      expect { get(url) }.to change(entries, :size).from(1).to(0)
    end

    it "keeps nothing once the server says not to keep the response that hasn't changed" do
      stub_fresh.then.to_return(status: 304, headers: {"Cache-Control" => "no-store"})
      get(url)
      wait(60)

      expect { get(url) }.to change(entries, :size).from(1).to(0)
    end

    it "keeps nothing at all for a response it doesn't keep, not even that it asked" do
      stub_request(:get, url).to_return(status: 404, body: "no")
      get(url)

      expect(entries).to eq({})
    end

    it "keeps what it keeps by URL and media type" do
      stub_fresh
      get(url)

      expect(entries.keys).to eq([[URI(url), "application/json"]])
    end

    it "answers with a 304 itself when it kept nothing for it to be about" do
      stub_request(:get, url).to_return(status: 304, headers: {"Cache-Control" => "public, max-age=60"})

      expect([get(url).code, get(url).code]).to eq(%w[304 304])
    end

    it "keeps each media type a URL is asked for as apart" do
      json = stub_fresh.with(headers: {"Accept" => "application/json"})
      text = stub_fresh(body: "text").with(headers: {"Accept" => "text/plain"})
      bodies = Array.new(2) { [get(url).body, get(url, "text/plain").body] }

      expect([bodies, made(json), made(text)]).to eq([[%w[one text], %w[one text]], 1, 1])
    end

    it "keeps each URL apart, to its query" do
      stub_fresh
      stub_fresh(body: "two", url: "#{url}?x=1")

      expect([get(url).body, get("#{url}?x=1").body, get(url).body]).to eq(%w[one two one])
    end

    it "sends anything but a GET each time, and keeps none of it" do
      request = stub_request(:post, url).to_return(body: "ok", headers: {"Cache-Control" => "public, max-age=60"})
      bodies = Array.new(2) { cache.request(Net::HTTP::Post.new(URI(url))).body }

      expect([bodies, made(request)]).to eq([%w[ok ok], 2])
    end

    it "doesn't answer a GET with what a POST to the same URL said" do
      stub_request(:post, url).to_return(body: "posted", headers: {"Cache-Control" => "public, max-age=60"})
      stub_fresh
      cache.request(Net::HTTP::Post.new(URI(url), {"Accept" => "application/json"}))

      expect(get(url).body).to eq("one")
    end

    it "holds its lock to read what it kept, and to keep what it gets" do
      stub_fresh
      allow(lock).to receive(:synchronize).and_call_original
      get(url)

      expect(lock).to have_received(:synchronize).twice
    end

    it "holds its lock only to read, for a response that's still good" do
      stub_fresh
      get(url)
      allow(lock).to receive(:synchronize).and_call_original
      get(url)

      expect(lock).to have_received(:synchronize).once
    end

    it "doesn't hold its lock while it waits for the server" do
      stub_request(:get, url).to_return { {body: lock.locked?.to_s} }

      expect(get(url).body).to eq("false")
    end

    it "raises what the connections do" do
      stub_request(:get, url).to_timeout

      expect { get(url) }.to raise_error(Sferik::Unanswered)
    end

    it "raises what the connections do though it kept a response, which is no longer good" do
      stub_fresh.then.to_timeout
      get(url)
      wait(60)

      expect { get(url) }.to raise_error(Sferik::Unanswered)
    end
  end

  context "when it's to answer with what's no longer good, if the server can't be reached" do
    let(:cache) { Sferik.const_get(:Cache).new(connections, -> { now.first }, entries, lock, stale: true) }

    it "answers with the response it kept, however old, when no answer comes" do
      stub_fresh.then.to_timeout
      first = get(url)
      wait(86_400)

      expect(get(url)).to be(first)
    end

    it "answers with the response it kept when the server can't be connected to" do
      stub_fresh
      first = get(url)
      wait(60)
      allow(Net::HTTP).to receive(:start).and_raise(SocketError, "getaddrinfo: nodename nor servname provided")

      expect(get(url)).to be(first)
    end

    it "asks again the next time, and keeps what the server says then" do
      request = stub_fresh.then.to_timeout.then.to_return(body: "two", headers: {"Cache-Control" => "public, max-age=60"})
      get(url)
      wait(60)

      expect([get(url).body, get(url).body, get(url).body, made(request)]).to eq(["one", "two", "two", 3])
    end

    it "raises when it kept nothing to answer with" do
      stub_request(:get, url).to_timeout

      expect { get(url) }.to raise_error(Sferik::Unanswered)
    end

    it "raises anything else that goes wrong, though it kept a response" do
      stub_fresh.then.to_raise(ArgumentError.new("not the network"))
      get(url)
      wait(60)

      expect { get(url) }.to raise_error(ArgumentError, "not the network")
    end

    it "answers with what the server says, when it says a response isn't there any more" do
      stub_fresh.then.to_return(status: 404)
      get(url)
      wait(60)

      expect(get(url).code).to eq("404")
    end

    it "yields a cache from keeping that answers with what's no longer good too" do
      stub_fresh.then.to_timeout
      first = get(url)
      wait(60)

      expect(cache.keeping { |kept| get(url, through: kept) }).to be(first)
    end
  end

  describe "#keeping" do
    it "yields a cache that doesn't answer with what's no longer good either, when the server can't be reached" do
      stub_fresh.then.to_timeout
      get(url)
      wait(60)

      expect { cache.keeping { |kept| get(url, through: kept) } }.to raise_error(Sferik::Unanswered)
    end

    it "yields a cache that answers with what this one kept" do
      request = stub_fresh
      get(url)

      expect([cache.keeping { |kept| get(url, through: kept).body }, made(request)]).to eq(["one", 1])
    end

    it "yields a cache that keeps what it gets for this one" do
      request = stub_fresh
      cache.keeping { |kept| get(url, through: kept) }

      expect([get(url).body, made(request)]).to eq(["one", 1])
    end

    it "yields a cache on the same clock" do
      request = stub_fresh
      cache.keeping { |kept| get(url, through: kept) && wait(60) && get(url, through: kept) }

      expect(request).to have_been_made.twice
    end

    it "yields a cache that holds the same lock" do
      stub_fresh
      allow(lock).to receive(:synchronize).and_call_original
      cache.keeping { |kept| get(url, through: kept) }

      expect(lock).to have_received(:synchronize).twice
    end

    it "yields a cache whose connections are kept open, and closes them afterwards" do
      stub_fresh
      stub_fresh(url: "https://sferik.net/talks")
      allow(Net::HTTP).to receive(:start).and_call_original
      cache.keeping { |kept| get(url, through: kept) && get("https://sferik.net/talks", through: kept) }

      expect(Net::HTTP).to have_received(:start).once
    end

    it "returns what the block returns" do
      expect(cache.keeping { :done }).to eq(:done)
    end
  end

  describe ".new" do
    let(:cache) { Sferik.const_get(:Cache).new(connections) }

    it "tells the time by a clock that only goes forward, and keeps what it gets, unless given others" do
      request = stub_fresh
      2.times { get(url) }

      expect(request).to have_been_made.once
    end

    it "keeps nothing another cache does, unless given what one keeps" do
      request = stub_fresh
      get(url)
      get(url, through: Sferik.const_get(:Cache).new(connections))

      expect(request).to have_been_made.twice
    end
  end
end
