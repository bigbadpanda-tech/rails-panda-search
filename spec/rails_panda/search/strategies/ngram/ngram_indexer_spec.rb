require "rails_helper"

RSpec.describe RailsPanda::Search::Strategies::Ngram::NgramIndexer do
  describe ".ngrams_for" do
    it "generates trigrams from a normal string" do
      result = described_class.ngrams_for("hello")
      expect(result).to contain_exactly("hel", "ell", "llo")
    end

    it "downcases the input" do
      result = described_class.ngrams_for("Hello")
      expect(result).to contain_exactly("hel", "ell", "llo")
    end

    it "strips whitespace" do
      result = described_class.ngrams_for("  hi  ")
      expect(result).to eq([])
    end

    it "returns empty array for strings shorter than n" do
      result = described_class.ngrams_for("ab")
      expect(result).to eq([])
    end

    it "returns a single ngram for string of exactly n length" do
      result = described_class.ngrams_for("abc")
      expect(result).to contain_exactly("abc")
    end

    it "returns unique ngrams" do
      result = described_class.ngrams_for("aaa")
      expect(result).to contain_exactly("aaa")
    end

    it "handles empty string" do
      expect(described_class.ngrams_for("")).to eq([])
    end

    it "handles nil" do
      expect(described_class.ngrams_for(nil)).to eq([])
    end

    it "handles unicode characters" do
      result = described_class.ngrams_for("café")
      expect(result).to contain_exactly("caf", "afé")
    end

    it "respects configured ngram_size" do
      original = RailsPanda::Search.config.ngram_size
      RailsPanda::Search.config.ngram_size = 4
      result = described_class.ngrams_for("hello")
      expect(result).to contain_exactly("hell", "ello")
    ensure
      RailsPanda::Search.config.ngram_size = original
    end

    it "generates ngrams per word for multi-word strings" do
      result = described_class.ngrams_for("alice krige")
      expect(result).to contain_exactly("ali", "lic", "ice", "kri", "rig", "ige")
    end

    it "normalizes tabs, newlines, and carriage returns to spaces" do
      result = described_class.ngrams_for("alice\tkrige\nbob\r\nsmith")
      expect(result).to include("ali", "kri", "bob", "smi")
      expect(result).not_to include("e\tk", "e\nb", "b\r\n")
    end

    it "collapses multiple spaces between words" do
      single = described_class.ngrams_for("alice krige")
      double = described_class.ngrams_for("alice  krige")
      expect(single).to eq(double)
    end

    it "skips words shorter than ngram_size" do
      result = described_class.ngrams_for("al krige")
      expect(result).to contain_exactly("kri", "rig", "ige")
    end
  end

  describe ".primary_key_hash" do
    it "returns a hash with the primary key" do
      record = TestRecord.create!(name: "Test", email: "test@example.com")
      result = described_class.primary_key_hash(record)
      expect(result).to eq({"id" => record.id})
    end
  end

  describe ".index_record!" do
    let(:record) { TestRecord.create!(name: "Alice Smith", email: "alice@example.com") }
    let(:entry_class) { RailsPanda::Search::Strategies::Ngram::NgramEntry }

    it "creates ngram entries for the given columns" do
      described_class.index_record!(record, [:name])

      entries = entry_class.where(source_type: "TestRecord", source_column: "name")
      expect(entries.count).to be_positive
      expect(entries.pluck(:ngram)).to include("ali", "lic", "ice")
    end

    it "is a pure insert (does not delete existing entries)" do
      count_before = entry_class.where(source_type: "TestRecord", source_column: "name").count

      described_class.index_record!(record, [:name])
      expect(entry_class.where(source_type: "TestRecord", source_column: "name").count).to be > count_before
    end

    it "skips columns with blank values" do
      blank_record = TestRecord.create!(name: nil, email: "test@example.com")
      entry_class.where(source_type: "TestRecord", source_id: described_class.primary_key_hash(blank_record)).delete_all

      described_class.index_record!(blank_record, [:name])
      entries = entry_class.where(
        source_type: "TestRecord",
        source_id: described_class.primary_key_hash(blank_record),
        source_column: "name"
      )
      expect(entries.count).to eq(0)
    end

    it "skips columns with empty string values" do
      empty_record = TestRecord.create!(name: "", email: "test@example.com")
      entry_class.where(source_type: "TestRecord", source_id: described_class.primary_key_hash(empty_record)).delete_all

      described_class.index_record!(empty_record, [:name])
      entries = entry_class.where(
        source_type: "TestRecord",
        source_id: described_class.primary_key_hash(empty_record),
        source_column: "name"
      )
      expect(entries.count).to eq(0)
    end
  end

  describe ".remove_record!" do
    let(:record) { TestRecord.create!(name: "Alice", email: "alice@example.com") }
    let(:entry_class) { RailsPanda::Search::Strategies::Ngram::NgramEntry }

    before do
      described_class.index_record!(record, [:name, :email])
    end

    it "removes all ngram entries for the record" do
      described_class.remove_record!(record)

      entries = entry_class.where(source_type: "TestRecord")
      expect(entries.count).to eq(0)
    end
  end
end
