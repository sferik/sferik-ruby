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

  describe "#name_change" do
    before { stub_get("/name", "name.json") }

    it "returns the name change" do
      expect(client.name_change).to have_attributes(year: 2017, commit: "8c0d698", subject: /Berlin/, notes: all(be_a(String)), command: /git log/)
    end
  end
end
