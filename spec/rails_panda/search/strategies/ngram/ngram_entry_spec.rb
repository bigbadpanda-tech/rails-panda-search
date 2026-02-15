require "rails_helper"

RSpec.describe RailsPanda::Search::Strategies::Ngram::NgramEntry do
  let(:entry_class) { described_class }

  describe "scopes" do
    before do
      entry_class.create!(ngram: "ali", source_type: "User", source_id: {"id" => 1}, source_column: "name")
      entry_class.create!(ngram: "lic", source_type: "User", source_id: {"id" => 1}, source_column: "name")
      entry_class.create!(ngram: "ali", source_type: "Contact", source_id: {"id" => 2}, source_column: "email")
    end

    describe ".for_ngram" do
      it "filters by ngram value" do
        expect(entry_class.for_ngram("ali").count).to eq(2)
      end
    end

    describe ".for_source_type" do
      it "filters by source_type" do
        expect(entry_class.for_source_type("User").count).to eq(2)
      end
    end

    describe ".for_column" do
      it "filters by source_column" do
        expect(entry_class.for_column(:name).count).to eq(2)
        expect(entry_class.for_column(:email).count).to eq(1)
      end
    end
  end

  describe ".matching_source_ids" do
    before do
      # User 1: "alice" in name → ali, lic, ice
      %w[ali lic ice].each do |ngram|
        entry_class.create!(ngram: ngram, source_type: "User", source_id: {"id" => 1}, source_column: "name")
      end

      # User 2: "alison" in name → ali, lis, iso, son
      %w[ali lis iso son].each do |ngram|
        entry_class.create!(ngram: ngram, source_type: "User", source_id: {"id" => 2}, source_column: "name")
      end

      # Contact 3: "alice" in email → ali, lic, ice
      %w[ali lic ice].each do |ngram|
        entry_class.create!(ngram: ngram, source_type: "Contact", source_id: {"id" => 3}, source_column: "email")
      end
    end

    it "returns source_ids matching all ngrams" do
      results = entry_class.matching_source_ids(%w[ali lic ice], source_type: "User")
      source_ids = results.map(&:last)
      expect(source_ids).to include({"id" => 1})
      expect(source_ids).not_to include({"id" => 2})
    end

    it "returns empty when no match" do
      results = entry_class.matching_source_ids(%w[xyz], source_type: "User")
      expect(results).to be_empty
    end

    it "returns empty for empty ngram list" do
      expect(entry_class.matching_source_ids([])).to be_empty
    end

    it "scopes by source_type" do
      results = entry_class.matching_source_ids(%w[ali lic ice], source_type: "Contact")
      source_types = results.map(&:first)
      expect(source_types).to all(eq("Contact"))
    end

    it "returns results from all types when source_type is nil" do
      results = entry_class.matching_source_ids(%w[ali lic ice])
      source_types = results.map(&:first).uniq
      expect(source_types).to contain_exactly("User", "Contact")
    end

    it "scopes by columns" do
      results = entry_class.matching_source_ids(%w[ali lic ice], columns: [:email])
      source_types = results.map(&:first)
      expect(source_types).to contain_exactly("Contact")
    end
  end
end
