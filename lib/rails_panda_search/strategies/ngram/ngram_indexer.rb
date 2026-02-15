# frozen_string_literal: true

module RailsPanda
  module Search
    module Strategies
      module Ngram
        class NgramIndexer
          class << self
            def ngrams_for(text)
              n = RailsPanda::Search.config.ngram_size

              text.to_s.downcase.split(" ").flat_map do |word|
                next [] if word.length < n

                (0..word.length - n).map { |i| word[i, n] }
              end.uniq
            end

            # Create ngram entries for a record's columns. Pure insert.
            def index_record!(record, columns)
              pk_hash = primary_key_hash(record)
              source_type = record.class.name

              columns.each do |column|
                value = record.send(column)
                next if value.blank?

                ngrams_for(value).each do |ngram|
                  NgramEntry.create!(
                    ngram: ngram,
                    source_type: source_type,
                    source_id: pk_hash,
                    source_column: column.to_s
                  )
                end
              end
            end

            # Remove all ngram entries for a record.
            def remove_record!(record)
              NgramEntry.where(
                source_type: record.class.name,
                source_id: primary_key_hash(record)
              ).delete_all
            end

            def primary_key_hash(record)
              pk = Array(record.class.primary_key)
              pk.each_with_object({}) { |key, hash| hash[key] = record.send(key) }
            end
          end
        end
      end
    end
  end
end
