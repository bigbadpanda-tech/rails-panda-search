# Create in-memory test schema
ActiveRecord::Schema.define do
  create_table :rails_panda_search_ngram_entries, force: true do |t|
    t.string :ngram, null: false
    t.string :source_type, null: false
    t.json :source_id, null: false
    t.string :source_column, null: false
    t.timestamps
  end

  add_index :rails_panda_search_ngram_entries, %i[ngram source_type],
    name: "idx_ngram_entries_on_ngram_and_source_type"

  create_table :test_records, force: true do |t|
    t.string :name
    t.string :email
    t.boolean :active, default: true
    t.timestamps
  end

  create_table :composite_pk_records, primary_key: %i[tenant_id record_id], force: true do |t|
    t.integer :tenant_id, null: false
    t.integer :record_id, null: false
    t.string :name
    t.string :email
    t.timestamps
  end
end

class TestRecord < ApplicationRecord
  encrypts :name, :email
  can_search_in :name, :email
end

class CompositePkRecord < ApplicationRecord
  self.primary_key = %i[tenant_id record_id]
  can_search_in :name, :email
end
