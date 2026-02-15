require "rails_helper"

RSpec.describe RailsPanda::Search::Config do
  subject(:config) { described_class.new }

  describe "#strategy_enabled?" do
    it "returns true for enabled strategies" do
      expect(config.strategy_enabled?(:ngram)).to be(true)
    end

    it "returns false for disabled strategies" do
      expect(config.strategy_enabled?(:elasticsearch)).to be(false)
    end

    it "returns true for registered custom strategies" do
      custom = Class.new(RailsPanda::Search::Strategies::Base)
      config.register_strategy(:custom, custom)
      expect(config.strategy_enabled?(:custom)).to be(true)
    end
  end

  describe "#register_strategy" do
    let(:valid_strategy) do
      Class.new(RailsPanda::Search::Strategies::Base)
    end

    it "registers a valid strategy class" do
      config.register_strategy(:custom, valid_strategy)
      expect(config.strategy_class_for(:custom)).to eq(valid_strategy)
    end

    it "raises ArgumentError for a class not inheriting from Base" do
      expect { config.register_strategy(:bad, String) }
        .to raise_error(ArgumentError, /must be a subclass of/)
    end

    it "raises ArgumentError for non-class values" do
      expect { config.register_strategy(:bad, "NotAClass") }
        .to raise_error(ArgumentError, /must be a subclass of/)
    end
  end

  describe "#strategy_class_for" do
    it "returns the built-in ngram strategy class" do
      expect(config.strategy_class_for(:ngram))
        .to eq(RailsPanda::Search::Strategies::Ngram::NgramStrategy)
    end

    it "prefers custom strategies over built-in" do
      custom = Class.new(RailsPanda::Search::Strategies::Base)
      config.register_strategy(:ngram, custom)
      expect(config.strategy_class_for(:ngram)).to eq(custom)
    end

    it "raises Error for unknown strategies" do
      expect { config.strategy_class_for(:unknown) }
        .to raise_error(RailsPanda::Search::Error, /Unknown strategy/)
    end
  end

  describe "#active_strategy_classes" do
    it "returns classes for all enabled strategies" do
      classes = config.active_strategy_classes
      expect(classes).to contain_exactly(RailsPanda::Search::Strategies::Ngram::NgramStrategy)
    end

    it "includes registered custom strategies even without adding to strategies array" do
      custom = Class.new(RailsPanda::Search::Strategies::Base)
      config.register_strategy(:custom, custom)

      classes = config.active_strategy_classes
      expect(classes).to contain_exactly(
        RailsPanda::Search::Strategies::Ngram::NgramStrategy,
        custom
      )
    end

    it "does not duplicate when custom strategy is also in strategies array" do
      custom = Class.new(RailsPanda::Search::Strategies::Base)
      config.register_strategy(:custom, custom)
      config.strategies = [:ngram, :custom]

      classes = config.active_strategy_classes
      expect(classes).to contain_exactly(
        RailsPanda::Search::Strategies::Ngram::NgramStrategy,
        custom
      )
    end
  end
end
