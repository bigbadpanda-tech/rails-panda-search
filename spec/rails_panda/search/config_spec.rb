require "rails_helper"

RSpec.describe RailsPanda::Search::Config do
  describe ".config" do
    it "returns a Config instance" do
      expect(RailsPanda::Search.config).to be_a(described_class)
    end

    it "memoizes the config" do
      config1 = RailsPanda::Search.config
      config2 = RailsPanda::Search.config

      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the config" do
      expect { |b| RailsPanda::Search.configure(&b) }.to yield_with_args(described_class)
    end

    it "allows configuration" do
      RailsPanda::Search.configure do |config|
        expect(config).to be_a(described_class)
      end
    end
  end
end
