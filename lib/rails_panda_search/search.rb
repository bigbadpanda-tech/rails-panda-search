# frozen_string_literal: true

require "rails_panda_search/config"

module RailsPanda
  module Search
    class Error < StandardError; end

    class << self
      # Search across ALL models that use can_search_in.
      # Returns a Hash of { "ModelName" => ActiveRecord::Relation, ... }
      #
      # Dispatches to all active strategies and merges results.
      #
      #   RailsPanda::Search.search_for("alice")
      #   # => { "User" => #<ActiveRecord::Relation [...]>, "Contact" => #<ActiveRecord::Relation [...]> }
      #
      def search_for(query)
        all_matches = config.active_strategy_classes.flat_map do |strategy|
          strategy.search(query)
        end

        return {} if all_matches.empty?

        models_by_name = searchable_models.index_by(&:name)

        all_matches
          .group_by(&:first)
          .each_with_object({}) do |(source_type, pairs), results|
            model = models_by_name[source_type]
            next unless model

            pk_hashes = pairs.map(&:last).uniq
            results[source_type] = model.send(:_relation_from_pk_hashes, pk_hashes)
          end
      end

      # Reindex all records across ALL searchable models.
      def reindex_search_all!
        searchable_models.each(&:reindex_search_all!)
      end

      private

      def searchable_models
        # :nocov:
        Rails.application.eager_load! if defined?(Rails) && Rails.application
        # :nocov:

        ::ActiveRecord::Base.descendants.select do |model|
          model.respond_to?(:searchable_columns) && model.searchable_columns.present?
        end
      end
    end
  end
end
