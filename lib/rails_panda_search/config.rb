# frozen_string_literal: true

module RailsPanda
  module Search
    class Config
      attr_writer :strategies
      attr_accessor :strategy_options
      attr_accessor :ngram_size, :ngram_entries_table_name

      # Maps strategy names to their implementation classes.
      # Register new strategies here or via Config#register_strategy.
      STRATEGY_REGISTRY = {
        ngram: "RailsPanda::Search::Strategies::Ngram::NgramStrategy"
      }.freeze

      DEFAULT_TABLE_PREFIX = "rails_panda_search"

      def initialize
        @strategies = [:ngram]
        @strategy_options = {}
        @custom_strategies = {}

        @ngram_size = 3
        @ngram_entries_table_name = "#{DEFAULT_TABLE_PREFIX}_ngram_entries"
      end

      def strategies
        (@strategies.map(&:to_sym) | @custom_strategies.keys)
      end

      def strategy_enabled?(name)
        strategies.include?(name.to_sym)
      end

      # Register a custom strategy implementation.
      # The class must be a subclass of Strategies::Base.
      #
      #   config.register_strategy(:elasticsearch, MyElasticsearchStrategy)
      #
      def register_strategy(name, klass)
        unless klass.is_a?(Class) && klass < Strategies::Base
          raise ArgumentError, "#{klass} must be a subclass of RailsPanda::Search::Strategies::Base"
        end

        @custom_strategies[name.to_sym] = klass
      end

      # Returns the implementation class for a given strategy name.
      def strategy_class_for(name)
        klass = @custom_strategies[name.to_sym]
        return klass if klass

        class_name = STRATEGY_REGISTRY[name.to_sym]
        if class_name
          class_name.constantize
        else
          raise Error, "Unknown strategy: #{name}. Register it with config.register_strategy."
        end
      end

      # Returns implementation classes for all enabled strategies.
      def active_strategy_classes
        strategies.map { |name| strategy_class_for(name) }
      end
    end

    class << self
      def configure
        yield config
      end

      def config
        @config ||= Config.new
      end
    end
  end
end
