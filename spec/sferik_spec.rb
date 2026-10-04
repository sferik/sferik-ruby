# frozen_string_literal: true

RSpec.describe Sferik do
  let(:mutex) { described_class.const_get(:CLIENT_MUTEX) }

  it "doesn't load the command, or optparse, until it's used" do
    # The library is required with -r, since JRuby's launcher on Windows drops the double quotes of a script
    script = "exit((Sferik.autoload?(:CLI) && !defined?(OptionParser)) ? 0 : 1)"

    expect(system(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-r", "sferik", "-e", script)).to be(true)
  end

  describe ".new" do
    it "builds a client with the options given" do
      expect(described_class.new(host: "http://localhost:3745").host).to eq("http://localhost:3745")
    end
  end

  describe ".client" do
    it "is built while holding the mutex" do
      allow(mutex).to receive(:synchronize).and_call_original
      described_class.client

      expect(mutex).to have_received(:synchronize)
    end

    it "is built from the global configuration" do
      described_class.host = "http://localhost:3745"

      expect(described_class.client.host).to eq("http://localhost:3745")
    end

    it "is the same client while the configuration is unchanged" do
      client = described_class.client

      expect(described_class.client).to be(client)
    end

    it "is built again when the configuration changes" do
      client = described_class.client
      described_class.read_timeout = 30

      expect([described_class.client.equal?(client), described_class.client.read_timeout]).to eq([false, 30])
    end
  end

  describe ".reset" do
    it "resets while holding the mutex" do
      allow(mutex).to receive(:synchronize).and_call_original
      described_class.reset

      expect(mutex).to have_received(:synchronize)
    end

    it "returns the module" do
      expect(described_class.reset).to be(described_class)
    end

    it "forgets the configuration" do
      described_class.host = "http://localhost:3745"
      described_class.reset

      expect(described_class.client.host).to eq("https://sferik.net")
    end

    it "forgets the client" do
      client = described_class.client
      described_class.reset

      expect(described_class.client).not_to be(client)
    end
  end

  describe "delegation" do
    it "sends an endpoint to the client" do
      stub_get("/whoami", "whoami.json")

      expect(described_class.whoami).to be_a(Sferik::Whoami)
    end

    it "offers every endpoint of the API" do
      expect(Sferik::API.public_instance_methods).to all(satisfy { |name| described_class.respond_to?(name) })
    end

    it "documents every public API method under the name it's called by, which YARD can't see in a delegation" do
      documented = File.read(File.expand_path("../lib/sferik.rb", __dir__)).scan(/^  # @!method self\.(\w+)/).flatten.map(&:to_sym)

      expect(documented - [:new]).to match_array(Sferik::API.public_instance_methods)
    end

    it "keeps the methods of SingleForwardable private" do
      expect(described_class).not_to respond_to(:def_delegator)
    end
  end
end
