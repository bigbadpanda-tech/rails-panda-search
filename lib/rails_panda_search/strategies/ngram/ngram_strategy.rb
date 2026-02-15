# frozen_string_literal: true

require "rails_panda_search/strategies/base"
require "rails_panda_search/strategies/ngram/ngram_entry"
require "rails_panda_search/strategies/ngram/ngram_indexer"

module RailsPanda
  module Search
    module Strategies
      module Ngram
        # N-gram search strategy implementation.
        # Conforms to the Strategies::Base interface.
        #
        # Breaks text into n-character substrings and stores them in a local
        # ActiveRecord table for fast substring matching.
        #
        # Uses the default Base#sync_record! (remove + index).
        #
        class NgramStrategy < Base
          class << self
            def index_record!(record, columns)
              NgramIndexer.index_record!(record, columns)
            end

            def remove_record!(record)
              NgramIndexer.remove_record!(record)
            end

            def clear_for_source_type!(source_type)
              NgramEntry.for_source_type(source_type).delete_all
            end

            def search(query, source_type: nil, columns: nil)
              ngrams = NgramIndexer.ngrams_for(query)
              return [] if ngrams.empty?

              NgramEntry.matching_source_ids(
                ngrams,
                source_type: source_type,
                columns: columns
              )
            end
          end
        end
      end
    end
  end
end
