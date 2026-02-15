# frozen_string_literal: true

require "active_support"
require "active_support/concern"

module RailsPanda
  module Search
    module Searchable
      extend ActiveSupport::Concern

      class_methods do
        # Declares which columns should be searchable via n-gram indexing.
        #
        #   class User < ApplicationRecord
        #     can_search_in :email, :name
        #   end
        #
        def can_search_in(*columns)
          raise ArgumentError, "can_search_in requires at least one column" if columns.empty?

          if respond_to?(:searchable_columns) && searchable_columns.present?
            self.searchable_columns |= columns.map(&:to_sym)
          else
            # :nocov:
            class_attribute :searchable_columns, instance_writer: false, default: []
            # :nocov:
            self.searchable_columns = columns.map(&:to_sym)

            after_save :_sync_search_index
            after_destroy :_remove_search_index

            include InstanceMethods
            extend SearchClassMethods
          end
        end
      end

      # Class methods added only to models that call can_search_in
      module SearchClassMethods
        # Search for records matching the given query string.
        # Returns an ActiveRecord::Relation.
        #
        # Dispatches to all active strategies and merges results.
        #
        #   User.search_for("alice")
        #   User.search_for("alice", columns: [:email])
        #   User.where(active: true).search_for("alice")
        #
        def search_for(query, columns: nil)
          all_matches = RailsPanda::Search.config.active_strategy_classes.flat_map do |strategy|
            strategy.search(query, source_type: name, columns: columns)
          end

          pk_hashes = all_matches.map(&:last).uniq
          return none if pk_hashes.empty?

          _relation_from_pk_hashes(pk_hashes)
        end

        # Reindex all records in this model across all active strategies.
        # Clears all existing entries first, then inserts fresh.
        def reindex_search_all!
          strategies = RailsPanda::Search.config.active_strategy_classes

          strategies.each { |strategy| strategy.clear_for_source_type!(name) }

          find_each do |record|
            strategies.each { |strategy| strategy.index_record!(record, record.searchable_columns) }
          end
        end

        private

        def _relation_from_pk_hashes(pk_hashes)
          pk_columns = Array(primary_key)

          if pk_columns.length == 1
            pk_col = pk_columns.first
            ids = pk_hashes.map { |h| h[pk_col] || h[pk_col.to_s] }
            where(pk_col => ids)
          else
            # Composite PK: build OR conditions
            pk_hashes.map { |pk_hash|
              condition = pk_columns.each_with_object({}) do |col, cond|
                cond[col] = pk_hash[col] || pk_hash[col.to_s]
              end
              where(condition)
            }.reduce(:or)
          end
        end
      end

      # Instance methods added only to models that call can_search_in
      module InstanceMethods
        # Rebuild this record's search index entries across all active strategies.
        def reindex_search!
          RailsPanda::Search.config.active_strategy_classes.each do |strategy|
            strategy.sync_record!(self, searchable_columns)
          end
        end

        private

        def _sync_search_index
          RailsPanda::Search.config.active_strategy_classes.each do |strategy|
            strategy.sync_record!(self, searchable_columns)
          end
        end

        def _remove_search_index
          RailsPanda::Search.config.active_strategy_classes.each do |strategy|
            strategy.remove_record!(self)
          end
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include RailsPanda::Search::Searchable
end
