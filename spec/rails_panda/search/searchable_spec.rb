require "rails_helper"

RSpec.describe RailsPanda::Search::Searchable do
  let(:entry_class) { RailsPanda::Search::Strategies::Ngram::NgramEntry }

  describe "can_search_in" do
    it "sets searchable_columns on the model" do
      expect(TestRecord.searchable_columns).to contain_exactly(:name, :email)
    end

    it "raises ArgumentError when called with no columns" do
      expect {
        Class.new(ApplicationRecord) do
          self.table_name = "test_records"
          can_search_in
        end
      }.to raise_error(ArgumentError, /at least one column/)
    end

    it "is additive when called multiple times" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "test_records"
        can_search_in :name
        can_search_in :email
      end

      expect(klass.searchable_columns).to contain_exactly(:name, :email)
    end

    it "does not duplicate columns when called with overlapping lists" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "test_records"
        can_search_in :name, :email
        can_search_in :email
      end

      expect(klass.searchable_columns).to contain_exactly(:name, :email)
    end
  end

  describe "after_save callback" do
    it "indexes the record after creation" do
      TestRecord.create!(name: "Alice Smith", email: "alice@example.com")

      entries = entry_class.where(source_type: "TestRecord")
      expect(entries.count).to be_positive

      name_ngrams = entries.where(source_column: "name").pluck(:ngram)
      expect(name_ngrams).to include("ali", "lic", "ice")
    end

    it "updates the index after update" do
      record = TestRecord.create!(name: "Alice", email: "alice@example.com")

      record.update!(name: "Bob Jones")

      name_ngrams = entry_class.where(
        source_type: "TestRecord",
        source_column: "name"
      ).pluck(:ngram)

      expect(name_ngrams).to include("bob", "jon", "one", "nes")
      expect(name_ngrams).not_to include("ali")
    end
  end

  describe "after_destroy callback" do
    it "removes the index after destruction" do
      record = TestRecord.create!(name: "Alice", email: "alice@example.com")
      expect(entry_class.where(source_type: "TestRecord").count).to be_positive

      record.destroy!
      expect(entry_class.where(source_type: "TestRecord").count).to eq(0)
    end
  end

  describe ".search_for" do
    before do
      TestRecord.create!(name: "Alice Smith", email: "alice@example.com")
      TestRecord.create!(name: "Bob Jones", email: "bob@example.com")
      TestRecord.create!(name: "Alicia Keys", email: "alicia@example.com")
    end

    it "returns records matching the query" do
      results = TestRecord.search_for("alice")
      # "alice" ngrams: ali, lic, ice
      # "Alice Smith" contains all three
      expect(results.count).to be >= 1
    end

    it "returns an ActiveRecord::Relation" do
      results = TestRecord.search_for("alice")
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "returns none for no matches" do
      results = TestRecord.search_for("zzzzz")
      expect(results).to be_empty
    end

    it "returns none for queries shorter than ngram_size" do
      results = TestRecord.search_for("ab")
      expect(results).to be_empty
    end

    it "is chainable with other scopes" do
      results = TestRecord.where(active: true).search_for("ali")
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "can scope to specific columns" do
      results = TestRecord.search_for("example", columns: [:email])
      expect(results.count).to be >= 1
    end
  end

  describe "#reindex_search!" do
    it "syncs the record's index" do
      record = TestRecord.create!(name: "Alice", email: "alice@example.com")

      # Manually delete some entries to simulate stale data
      entry_class.where(source_column: "name").limit(1).delete_all

      record.reindex_search!

      # Should be fully restored
      name_entries = entry_class.where(source_type: "TestRecord", source_column: "name")
      expect(name_entries.pluck(:ngram)).to include("ali", "lic", "ice")
    end
  end

  describe ".reindex_search_all!" do
    it "reindexes all records" do
      TestRecord.create!(name: "Alice", email: "alice@example.com")
      TestRecord.create!(name: "Bob", email: "bob@example.com")

      # Wipe the index
      entry_class.delete_all
      expect(entry_class.count).to eq(0)

      # Reindex
      TestRecord.reindex_search_all!

      expect(entry_class.count).to be_positive
      expect(entry_class.where(source_type: "TestRecord").count).to be_positive
    end
  end

  describe "composite primary key support" do
    it "indexes and searches with composite primary keys" do
      record = CompositePkRecord.create!(tenant_id: 1, record_id: 100, name: "Alice Smith", email: "alice@example.com")

      results = CompositePkRecord.search_for("alice")
      expect(results).to include(record)
    end

    it "returns correct records after reindex with composite keys" do
      record = CompositePkRecord.create!(tenant_id: 2, record_id: 200, name: "Bob Jones", email: "bob@test.com")

      entry_class.delete_all
      record.reindex_search!

      results = CompositePkRecord.search_for("bob")
      expect(results).to include(record)
    end

    it "removes entries on destroy with composite keys" do
      record = CompositePkRecord.create!(tenant_id: 3, record_id: 300, name: "Charlie", email: "charlie@test.com")
      expect(entry_class.where(source_type: "CompositePkRecord").count).to be_positive

      record.destroy!
      expect(entry_class.where(source_type: "CompositePkRecord").count).to eq(0)
    end
  end
end
