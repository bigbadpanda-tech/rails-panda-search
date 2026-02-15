require "rails_helper"

RSpec.describe RailsPanda::Search do
  describe "::Error" do
    it "is a StandardError subclass" do
      expect(described_class::Error.new).to be_a(StandardError)
    end
  end

  describe ".config" do
    it "returns a Config instance" do
      expect(described_class.config).to be_a(described_class::Config)
    end

    it "is memoized" do
      config = described_class.config
      expect(described_class.config).to be(config)
    end
  end

  describe ".configure" do
    it "yields the config" do
      described_class.configure do |config|
        expect(config).to be(described_class.config)
      end
    end
  end

  describe ".search_for" do
    before do
      TestRecord.create!(name: "Alice Smith", email: "alice@example.com")
      TestRecord.create!(name: "Bob Jones", email: "bob@example.com")
    end

    it "returns a hash of model name to relations" do
      results = described_class.search_for("alice")
      expect(results).to be_a(Hash)
      expect(results.keys).to include("TestRecord")
      expect(results["TestRecord"]).to be_a(ActiveRecord::Relation)
    end

    it "returns empty hash for no matches" do
      results = described_class.search_for("zzzzz")
      expect(results).to eq({})
    end

    it "skips unknown source types from strategy results" do
      allow(described_class.config.active_strategy_classes.first).to receive(:search)
        .and_return([["NonExistentModel", {"id" => 999}]])

      results = described_class.search_for("anything")
      expect(results).not_to have_key("NonExistentModel")
    end
  end

  describe ".reindex_search_all!" do
    it "reindexes all searchable models" do
      TestRecord.create!(name: "Alice", email: "alice@example.com")

      entry_class = RailsPanda::Search::Strategies::Ngram::NgramEntry
      entry_class.delete_all
      expect(entry_class.count).to eq(0)

      described_class.reindex_search_all!
      expect(entry_class.count).to be_positive
    end
  end
end
