require "rails_helper"

RSpec.describe RailsPanda::Search::Strategies::Base do
  describe ".index_record!" do
    it "raises NotImplementedError" do
      expect { described_class.index_record!(double, [:name]) }
        .to raise_error(NotImplementedError, /must implement .index_record!/)
    end
  end

  describe ".remove_record!" do
    it "raises NotImplementedError" do
      expect { described_class.remove_record!(double) }
        .to raise_error(NotImplementedError, /must implement .remove_record!/)
    end
  end

  describe ".clear_for_source_type!" do
    it "raises NotImplementedError" do
      expect { described_class.clear_for_source_type!("TestRecord") }
        .to raise_error(NotImplementedError, /must implement .clear_for_source_type!/)
    end
  end

  describe ".sync_record!" do
    it "calls remove_record! then index_record! by default" do
      record = double
      columns = [:name]

      allow(described_class).to receive(:remove_record!)
      allow(described_class).to receive(:index_record!)

      described_class.sync_record!(record, columns)

      expect(described_class).to have_received(:remove_record!).with(record).ordered
      expect(described_class).to have_received(:index_record!).with(record, columns).ordered
    end
  end

  describe ".search" do
    it "raises NotImplementedError" do
      expect { described_class.search("query") }
        .to raise_error(NotImplementedError, /must implement .search/)
    end
  end
end
