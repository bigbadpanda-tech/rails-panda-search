# frozen_string_literal: true

module RailsPanda
  module Search
    module Strategies
      module Ngram
        # == Schema Information
        #
        # Table name: rails_panda_search_ngram_entries
        #
        #  id            :integer          not null, primary key
        #  ngram         :string           not null
        #  source_type   :string           not null
        #  source_column :string           not null
        #  source_id     :json             not null
        #  created_at    :datetime         not null
        #  updated_at    :datetime         not null
        #
        # Indexes
        #
        #  idx_rails_panda_search_ngram_entries_on_ngram_and_source_type  (ngram,source_type)
        #
        class NgramEntry < ::ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
          self.table_name = RailsPanda::Search.config.ngram_entries_table_name

          scope :for_ngram, ->(ngram) { where(ngram: ngram) }
          scope :for_source_type, ->(type) { where(source_type: type) }
          scope :for_column, ->(column) { where(source_column: column.to_s) }

          # Returns source_id hashes that match ALL given n-grams.
          # Optionally scoped by source_type and/or columns.
          #
          # @param ngrams [Array<String>] n-grams to match
          # @param source_type [String, nil] model name to scope to (nil = global)
          # @param columns [Array<Symbol>, nil] columns to scope to (nil = all)
          # @return [Array<Hash>] matching source_id JSONB hashes
          def self.matching_source_ids(ngrams, source_type: nil, columns: nil)
            return [] if ngrams.empty?

            where(ngram: ngrams)
              .then do |scope|
                if source_type
                  scope.for_source_type(source_type)
                else
                  scope
                end
              end
              .then do |scope|
                if columns
                  scope.where(source_column: Array(columns).map(&:to_s))
                else
                  scope
                end
              end
              .group(:source_type, :source_id)
              .having("COUNT(DISTINCT ngram) = ?", ngrams.length)
              .pluck(:source_type, :source_id)
          end
        end
      end
    end
  end
end
