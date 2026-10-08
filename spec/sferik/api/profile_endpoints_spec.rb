# frozen_string_literal: true

RSpec.describe Sferik::API::ProfileEndpoints do
  let(:client) { Sferik::Client.new }

  describe "#home" do
    before { stub_get("/", "home.json") }

    it "returns the profile" do
      expect(client.home.profile).to have_attributes(name: "Erik Berlin", handle: "sferik", location: String, tagline: String, url: String)
    end

    it "returns the modules, in order" do
      expect(client.home.modules.map { |section| [section.id, section.url] }.first(2)).to eq([%w[whoami /whoami], %w[dependency /dependency]])
    end

    it "returns the pages" do
      expect(client.home.pages).to have_attributes(talks: "/talks", resume: "/resume")
    end
  end

  describe "#whoami" do
    before { stub_get("/whoami", "whoami.json") }

    it "returns the command and the downloads" do
      whoami = client.whoami

      expect([whoami.command, whoami.multi_downloads > 1_000_000_000]).to eq(["whoami", true])
    end

    it "returns paragraphs" do
      expect(client.whoami.blocks.first).to have_attributes(type: "p", html: /two decades/)
    end
  end

  describe "#dependency" do
    before { stub_get("/dependency", "dependency.json") }

    it "returns the command" do
      expect(client.dependency.command).to eq("imgcat ~/dependency.webp")
    end

    it "returns the comic" do
      expect(client.dependency.figure).to have_attributes(type: "figure", href: "https://xkcd.com/2347/", width: Integer, height: Integer,
        src: String, srcset: String, alt: String, title: String, caption: /xkcd/)
    end
  end

  describe "#finger" do
    before { stub_get("/finger", "finger.json") }

    it "returns contact details" do
      expect(client.finger).to have_attributes(login: "sferik", name: "Erik Berlin", mail: "sferik@gmail.com", command: "finger sferik",
        directory: String, shell: String, plan: String)
    end

    it "returns profiles" do
      expect(client.finger.profiles.first).to have_attributes(network: "GitHub", username: "sferik", url: "https://github.com/sferik", icon: String,
        aliases: include("github"))
    end
  end

  describe "#finger_vcard" do
    before { stub_get("/finger", "finger.vcf", accept: "text/vcard") }

    # Line by line, since a vCard's lines end with CRLF, which Ruby on Windows reads from the fixture as LF
    it "asks for a contact card" do
      expect(client.finger_vcard.lines(chomp: true)).to start_with("BEGIN:VCARD", "VERSION:3.0").and(include("FN:Erik Berlin")).and(end_with("END:VCARD"))
    end

    it "returns it as UTF-8, which the site says it is" do
      expect(client.finger_vcard.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe "#name_change" do
    before { stub_get("/name", "name.json") }

    it "returns the name change" do
      expect(client.name_change).to have_attributes(year: 2017, commit: "8c0d698", subject: /Berlin/, notes: all(be_a(String)), command: /git log/)
    end
  end

  describe "#signature" do
    it "returns the motto, asked for as text, without the newline the site ends it with" do
      stub_get("/.signature", "signature.txt", accept: "text/plain")

      expect(client.signature).to eq("I build libraries and tools software engineers depend on.")
    end
  end

  describe "#webfinger" do
    # Stub WebFinger for an account, asked for as a JSON Resource Descriptor
    def stub_webfinger(resource)
      stub_get("/.well-known/webfinger?resource=#{resource}", "webfinger.json", accept: "application/jrd+json")
    end

    it "returns where sferik@sferik.net points to" do
      stub_webfinger("acct%3Asferik%40sferik.net")

      expect(client.webfinger).to have_attributes(subject: "acct:sferik@mastodon.social", aliases: include("https://mastodon.social/@sferik"))
    end

    it "returns what the account links to, by URL or by a template for one" do
      stub_webfinger("acct%3Asferik%40sferik.net")

      expect(client.webfinger.links.values_at(0, -1)).to match([
        have_attributes(rel: "http://webfinger.net/rel/profile-page", type: "text/html", href: "https://mastodon.social/@sferik", template: nil),
        have_attributes(rel: "http://ostatus.org/schema/1.0/subscribe", type: nil, href: nil, template: /\{uri\}\z/)
      ])
    end

    it "asks after the account it's given, with whatever can't be in a query as it is escaped" do
      request = stub_webfinger("acct%3Asferik%2Bx%40sferik.org")
      client.webfinger("acct:sferik+x@sferik.org")

      expect(request).to have_been_made
    end

    it "raises NotFound for an account there isn't" do
      stub_request(:get, "https://sferik.net/.well-known/webfinger?resource=acct%3Anobody%40example.com")
        .to_return(status: 404, body: '{"error":"No such account: acct:nobody@example.com","code":"no_account"}', headers: {"Content-Type" => "application/json; charset=utf-8"})

      expect { client.webfinger("acct:nobody@example.com") }
        .to raise_error(an_instance_of(Sferik::NotFound).and(have_attributes(message: "No such account: acct:nobody@example.com", error_code: "no_account")))
    end

    it "raises ArgumentError for an account that isn't a String, before asking" do
      expect { client.webfinger(:sferik) }.to raise_error(ArgumentError, "resource must be String, not :sferik")
    end

    it "shows the account it points to when it's inspected" do
      stub_webfinger("acct%3Asferik%40sferik.net")

      expect(client.webfinger.inspect).to include('subject="acct:sferik@mastodon.social"')
    end
  end
end
