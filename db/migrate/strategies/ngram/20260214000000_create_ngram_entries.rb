# frozen_string_literal: true

class CreateNgramEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :rails_panda_search_ngram_entries do |t|
      t.string :ngram, null: false
      t.string :source_type, null: false
      t.string :source_column, null: false
      t.json :source_id, null: false

      t.timestamps
    end

    add_index :rails_panda_search_ngram_entries, %i[ngram source_type], name: "idx_rails_panda_search_ngram_entries_on_ngram_and_source_type"
  end
end
