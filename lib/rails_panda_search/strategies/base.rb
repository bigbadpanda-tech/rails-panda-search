# frozen_string_literal: true

module RailsPanda
  module Search
    module Strategies
      # Abstract base class that all search strategies must implement.
      #
      # A strategy is responsible for:
      # - Indexing record data (creating entries in whatever backend)
      # - Removing indexed data when records change or are destroyed
      # - Searching for records matching a query string
      #
      # Subclasses must implement: index_record!, remove_record!,
      # clear_for_source_type!, and search.
      #
      # sync_record! has a default implementation (remove + index) that
      # can be overridden for more efficient incremental updates.
      #
      # See Strategies::Ngram::NgramStrategy for a reference implementation.
      #
      class Base
        class << self
          # Create index entries for a record's searchable columns.
          # This is a pure insert — it does NOT delete old entries.
          #
          # @param record [ActiveRecord::Base] the record to index
          # @param columns [Array<Symbol>] columns to index
          def index_record!(record, columns)
            raise NotImplementedError, "#{name} must implement .index_record!"
          end

          # Remove all index entries for a record.
          # Called after a record is destroyed.
          #
          # @param record [ActiveRecord::Base] the record to remove
          def remove_record!(record)
            raise NotImplementedError, "#{name} must implement .remove_record!"
          end

          # Remove ALL index entries for a given source type.
          # Called before a full reindex to clear orphaned entries.
          #
          # @param source_type [String] the model name to clear entries for
          def clear_for_source_type!(source_type)
            raise NotImplementedError, "#{name} must implement .clear_for_source_type!"
          end

          # Sync a record's index: delete old entries, then insert new ones.
          # Called on after_save and manual reindex.
          #
          # Default: remove_record! + index_record!.
          # Override for more efficient incremental updates.
          #
          # @param record [ActiveRecord::Base] the record to sync
          # @param columns [Array<Symbol>] columns to sync
          def sync_record!(record, columns)
            remove_record!(record)
            index_record!(record, columns)
          end

          # Search for records matching the given query.
          # Must return an array of [source_type, source_id] pairs,
          # where source_id is a Hash of primary key column(s) to value(s).
          #
          # @param query [String] the search query
          # @param source_type [String, nil] model name to scope to (nil = global)
          # @param columns [Array<Symbol>, nil] columns to scope to (nil = all)
          # @return [Array<Array(String, Hash)>] matching [source_type, source_id] pairs
          def search(query, source_type: nil, columns: nil)
            raise NotImplementedError, "#{name} must implement .search"
          end
        end
      end
    end
  end
end
