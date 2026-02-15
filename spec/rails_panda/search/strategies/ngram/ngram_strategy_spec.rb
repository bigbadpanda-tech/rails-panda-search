require "rails_helper"

RSpec.describe RailsPanda::Search::Strategies::Ngram::NgramStrategy do
  let(:entry_class) { RailsPanda::Search::Strategies::Ngram::NgramEntry }

  describe ".index_record!" do
    it "creates ngram entries for the given columns" do
      record = TestRecord.create!(name: "Alice", email: "alice@example.com")

      described_class.index_record!(record, [:name])

      entries = entry_class.where(source_type: "TestRecord", source_column: "name")
      expect(entries.pluck(:ngram)).to include("ali", "lic", "ice")
    end
  end

  describe ".remove_record!" do
    it "removes all entries for the record" do
      record = TestRecord.create!(name: "Alice", email: "alice@example.com")
      described_class.index_record!(record, [:name, :email])
      expect(entry_class.where(source_type: "TestRecord").count).to be_positive

      described_class.remove_record!(record)
      expect(entry_class.where(source_type: "TestRecord").count).to eq(0)
    end
  end

  describe ".sync_record!" do
    it "removes old entries and inserts new ones" do
      record = TestRecord.create!(name: "Alice", email: "alice@example.com")
      described_class.index_record!(record, [:name])

      record.update_columns(name: "Bob") # rubocop:disable Rails/SkipsModelValidations
      record.reload
      described_class.sync_record!(record, [:name])

      ngrams = entry_class.where(source_type: "TestRecord", source_column: "name").pluck(:ngram)
      expect(ngrams).to contain_exactly("bob")
    end
  end

  describe ".search" do
    before do
      record = TestRecord.create!(name: "Alice Smith", email: "alice@example.com")
      described_class.index_record!(record, [:name, :email])
    end

    it "returns matching source_id pairs" do
      results = described_class.search("alice", source_type: "TestRecord")
      expect(results).not_to be_empty
      expect(results.first.first).to eq("TestRecord")
    end

    it "returns empty for queries shorter than ngram_size" do
      results = described_class.search("ab", source_type: "TestRecord")
      expect(results).to be_empty
    end

    it "returns empty for non-matching queries" do
      results = described_class.search("zzzzz", source_type: "TestRecord")
      expect(results).to be_empty
    end

    it "scopes by columns" do
      results = described_class.search("alice", source_type: "TestRecord", columns: [:name])
      expect(results).not_to be_empty
    end
  end
end
