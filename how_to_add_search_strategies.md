# How to Add New Search Strategies

This guide explains how to add a new search strategy to `rails-panda-search`. A strategy is a pluggable backend that knows how to index record data and search through it.

## Architecture Overview

```text
lib/rails_panda_search/
├── strategies/
│   ├── base.rb                      # Abstract interface + default sync_record!
│   └── ngram/                       # Reference implementation
│       ├── ngram_strategy.rb        # Implements Base interface
│       ├── ngram_indexer.rb         # Indexing logic
│       └── ngram_entry.rb           # AR model (local DB storage)
├── searchable.rb                    # Dispatches to active strategies
├── config.rb                        # Strategy registry + settings
└── engine.rb                        # Strategy-gated migration loading
```

The **Searchable concern** and **Search module** never reference a specific strategy directly. They iterate over `config.active_strategy_classes` and call the methods defined in `Strategies::Base`.

## The Strategy Interface

Every strategy must inherit from `RailsPanda::Search::Strategies::Base` and implement 4 abstract class methods. A 5th method, `sync_record!`, has a default implementation (remove + index) that can be overridden.

```ruby
class MyStrategy < RailsPanda::Search::Strategies::Base
  class << self
    # Create index entries for a record's columns.
    # This is a pure insert — it does NOT delete old entries.
    def index_record!(record, columns)
      # record  => an ActiveRecord instance
      # columns => [:name, :email, ...] (symbols)
    end

    # Remove ALL index entries for a record.
    # Called after a record is destroyed.
    def remove_record!(record)
    end

    # Remove ALL index entries for a given source type (model).
    # Called before a full reindex to clear orphaned entries.
    def clear_for_source_type!(source_type)
      # source_type => "User", "Contact", etc.
    end

    # Search for records matching a query string.
    # MUST return an Array of [source_type, source_id] pairs:
    #
    #   [
    #     ["User", {"id" => 1}],
    #     ["User", {"id" => 42}],
    #     ["Contact", {"tenant_id" => 5, "id" => 3}],
    #   ]
    #
    # source_type is the model class name (String).
    # source_id is a Hash mapping primary key column(s) to value(s).
    #
    # Parameters:
    #   query       => the search string
    #   source_type => model name to scope to (nil = all models)
    #   columns     => column names to scope to (nil = all columns)
    def search(query, source_type: nil, columns: nil)
    end

    # --- Optional override ---

    # Sync a record's index: delete old entries, then insert new ones.
    # Called on after_save and manual reindex.
    #
    # Default: remove_record!(record) + index_record!(record, columns).
    # Override for more efficient incremental updates.
    # def sync_record!(record, columns)
    #   remove_record!(record)
    #   index_record!(record, columns)
    # end
  end
end
```

> **Key contract:** `search` must return `[[source_type, source_id_hash], ...]`. The Searchable concern uses these to build an `ActiveRecord::Relation` via `WHERE id IN (...)`. If your strategy returns IDs that don't exist in the database, they'll simply be filtered out by ActiveRecord.

## Step-by-Step: Adding a Strategy

### 1. Create the strategy directory

```text
lib/rails_panda_search/strategies/your_strategy/
```

### 2. Implement the strategy class

Create `your_strategy.rb` inheriting from `Base`:

```ruby
# lib/rails_panda_search/strategies/your_strategy/your_strategy.rb
require "rails_panda_search/strategies/base"

module RailsPanda
  module Search
    module Strategies
      module YourStrategy
        class YourStrategy < Base
          class << self
            def index_record!(record, columns)
              columns.each do |col|
                value = record.send(col)
                next if value.blank?

                # Store index data in your backend
                # e.g., push to Elasticsearch, write to Redis, etc.
              end
            end

            def remove_record!(record)
              # Remove all index data for this record from your backend
            end

            def clear_for_source_type!(source_type)
              # Remove all index data for this model from your backend
            end

            def search(query, source_type: nil, columns: nil)
              # Query your backend, return matching records as:
              # [["ModelName", {"id" => 1}], ["ModelName", {"id" => 2}], ...]
            end

            # Override sync_record! only if you can do better than remove + index.
            # The default implementation (inherited from Base) works fine for most backends.
          end
        end
      end
    end
  end
end
```

### 3. Add a migration (if the strategy uses local DB storage)

Create a migration directory:

```text
db/migrate/strategies/your_strategy/
└── 20260215000000_create_your_strategy_table.rb
```

The Engine automatically appends migration paths for enabled strategies. If your strategy doesn't need a local table (e.g., Elasticsearch), skip this step — no directory means no migration.

### 4. Register the strategy

You have two options:

#### Option A: Built-in strategy (maintained in this gem)

Add it to `STRATEGY_REGISTRY` in `config.rb`:

```ruby
STRATEGY_REGISTRY = {
  ngram: "RailsPanda::Search::Strategies::Ngram::NgramStrategy",
  your_strategy: "RailsPanda::Search::Strategies::YourStrategy::YourStrategy",
}.freeze
```

#### Option B: External strategy (in a separate gem or the host app)

Register it at runtime in the host app's initializer:

```ruby
# config/initializers/rails_panda_search.rb
RailsPanda::Search.configure do |config|
  config.strategies = [:ngram, :elasticsearch]
  config.register_strategy(:elasticsearch, MyElasticsearchStrategy)

  # Strategy-specific options
  config.strategy_options[:elasticsearch] = {
    url: "http://localhost:9200",
    index_name: "search_index",
  }
end
```

Access options from within your strategy:

```ruby
def self.search(query, source_type: nil, columns: nil)
  opts = RailsPanda::Search.config.strategy_options[:elasticsearch]
  client = Elasticsearch::Client.new(url: opts[:url])
  # ... query the client ...
end
```

### 5. Add requires

If the strategy is built-in, add it to `lib/rails_panda_search.rb`:

```ruby
require "rails_panda_search/strategies/your_strategy/your_strategy"
```

### 6. Enable it

```ruby
RailsPanda::Search.configure do |config|
  config.strategies = [:ngram, :your_strategy]
end
```

## How Multi-Strategy Dispatch Works

When multiple strategies are enabled, the gem dispatches to **all** of them:

- **Saving:** `after_save` calls `sync_record!` on every active strategy (remove old + insert new)
- **Destruction:** `after_destroy` calls `remove_record!` on every active strategy
- **Searching:** `search_for` calls `search` on every active strategy, merges and deduplicates the results, then builds one `ActiveRecord::Relation`
- **Per-record reindex:** `reindex_search!` calls `sync_record!` on every active strategy
- **Bulk reindex:** `reindex_search_all!` calls `clear_for_source_type!` then `index_record!` per record on every active strategy

This means you can run multiple strategies in parallel (e.g., ngram for fast local search + Elasticsearch for full-text search) and they'll both be kept in sync automatically.

## Examples of Possible Strategies

| Strategy         | Backend                   | Use case                                                         |
| ---------------- | ------------------------- | ---------------------------------------------------------------- |
| `:ngram`         | Local DB table            | Substring search on encrypted columns (ships with gem)           |
| `:elasticsearch` | Elasticsearch cluster     | Full-text search with ranking, fuzzy matching                    |
| `:redis`         | Redis                     | Fast in-memory search for small datasets                         |
| `:bloom`         | Local DB (bloom filters)  | Space-efficient probabilistic matching                           |
| `:remote_api`    | HTTP API                  | Delegate search to an external service                           |

## Testing Your Strategy

Write specs that verify the interface methods. Use the existing ngram specs as a reference:

- `spec/rails_panda/search/strategies/ngram/ngram_indexer_spec.rb`
- `spec/rails_panda/search/strategies/ngram/ngram_entry_spec.rb`

Key things to test:

1. `index_record!` stores data correctly (pure insert, no deletes)
2. `remove_record!` cleans up all data for the record
3. `clear_for_source_type!` cleans up all data for a model
4. `sync_record!` does remove + index (if you override the default)
5. `search` returns the correct `[source_type, source_id]` pairs
6. `search` respects `source_type:` and `columns:` filters
7. Edge cases: empty queries, short queries, unicode, nil values
