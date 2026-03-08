require "rails_helper"

RSpec.describe RailsPanda::Search::Engine do
  it "is a Rails::Engine" do
    expect(described_class.superclass).to eq(::Rails::Engine)
  end

  it "isolates the RailsPanda::Search namespace" do
    expect(described_class.isolated?).to be(true)
  end

  describe "initializer: rails_panda_search.check_ngram_size" do
    let(:entry_class) { RailsPanda::Search::Strategies::Ngram::NgramEntry }
    let(:initializer) do
      described_class.initializers.find { |i| i.name == "rails_panda_search.check_ngram_size" }
    end

    before { entry_class.delete_all }

    it "warns when existing ngram length mismatches configured size" do
      entry_class.create!(
        ngram: "ab", source_type: "Test",
        source_id: {"id" => 1}.to_json, source_column: "name"
      )

      allow(Rails.logger).to receive(:warn)
      initializer.run(Rails.application)

      expect(Rails.logger).to have_received(:warn).with(/WARNING.*ngram_size/)
    end

    it "does not warn when ngram length matches configured size" do
      entry_class.create!(
        ngram: "abc", source_type: "Test",
        source_id: {"id" => 1}.to_json, source_column: "name"
      )

      allow(Rails.logger).to receive(:warn)
      initializer.run(Rails.application)

      expect(Rails.logger).not_to have_received(:warn)
    end

    it "does not warn when no entries exist" do
      allow(Rails.logger).to receive(:warn)
      initializer.run(Rails.application)

      expect(Rails.logger).not_to have_received(:warn)
    end
  end
end
