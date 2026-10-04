# frozen_string_literal: true

RSpec.describe Sferik::Configuration do
  describe "#options" do
    it "has defaults" do
      expect(Sferik.options).to eq(host: "https://sferik.net", user_agent: Sferik.user_agent, open_timeout: 5, read_timeout: 10, write_timeout: 10, max_redirects: 10)
    end

    it "freezes the default user agent, so that changing it in place can't change the default" do
      expect(Sferik.user_agent).to be_frozen
    end

    it "names the library and Ruby in the default user agent" do
      expect(Sferik.user_agent).to eq("sferik/#{Sferik::VERSION} (#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}; +https://rubygems.org/gems/sferik)")
    end

    it "keeps a setting assigned nil, rather than falling back to its default" do
      Sferik.user_agent = nil

      expect(Sferik.options[:user_agent]).to be_nil
    end
  end

  describe "#configure" do
    it "returns the module" do
      expect(Sferik.configure { |_config| nil }).to be(Sferik)
    end

    it "changes the settings in a block" do
      settings = {host: "http://localhost:3745", user_agent: "test", open_timeout: 1, read_timeout: 2, write_timeout: 4, max_redirects: 3}
      Sferik.configure { |config| settings.each { |setting, value| config.public_send(:"#{setting}=", value) } }

      expect(Sferik.options).to eq(settings)
    end

    it "raises ArgumentError without a block" do
      expect { Sferik.configure }.to raise_error(ArgumentError, "configure must be given a block")
    end
  end

  describe ".extended" do
    it "starts a module it extends at the defaults" do
      expect(Module.new.extend(described_class).options).to eq(Sferik.options)
    end
  end

  describe "#reset" do
    it "puts every setting back to its default" do
      Sferik.host = "http://localhost:3745"

      expect(Sferik.reset.host).to eq("https://sferik.net")
    end
  end
end
