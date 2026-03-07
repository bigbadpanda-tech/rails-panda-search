# Rails Panda Search

A Rails gem that enables **substring search on encrypted columns** using pluggable indexing strategies. When columns are encrypted (e.g., via Rails' `encrypts`), traditional SQL `LIKE` queries don't work — this gem solves that by maintaining a search index and using it to locate matching records. Ships with n-gram indexing out of the box.

## Features

- **Pluggable strategies** — Abstract interface supports any indexing backend (local DB, Elasticsearch, remote API, etc.)
- **N-gram indexing (built-in)** — Breaks column values into n-character substrings (trigrams by default) for fast substring matching
- **Multiple concurrent strategies** — Run several strategies simultaneously; results are merged automatically
- **Custom strategy registration** — Register your own strategies at runtime via `config.register_strategy`
- **Composite primary key support** — Primary keys stored as JSONB, supporting single and multi-column PKs
- **ActiveRecord integration** — `can_search_in` DSL adds search helpers directly to your models
- **Chainable scopes** — `search_for` returns an `ActiveRecord::Relation` you can chain with other scopes
- **Automatic indexing** — `after_save` / `after_destroy` callbacks keep the index in sync
- **Manual reindexing** — `reindex_search!` (per-record) and `reindex_search_all!` (per-model or global)
- **Global search** — `RailsPanda::Search.search_for` searches across all searchable models at once

## Installation

Add to your Gemfile:

```ruby
gem "rails-panda-search"
```

Then run:

```bash
bundle install
rails db:migrate
```

The gem ships as a Rails Engine that automatically appends its migrations to your app — no install generator needed.

## Configuration

Create an initializer at `config/initializers/rails_panda_search.rb`:

```ruby
RailsPanda::Search.configure do |config|
  # Which search strategies to enable (default: [:ngram])
  config.strategies = [:ngram]

  # N-gram strategy options
  config.ngram_size = 3  # default: 3 (trigrams)

  # N-gram storage table (for the built-in n-gram strategy)
  # Default: "rails_panda_search_ngram_entries"
  # Change this BEFORE running the engine migrations on a fresh app,
  # or add your own migration to rename the table in an existing app.
  # config.ngram_entries_table_name = "my_custom_search_ngrams"

  # Register custom strategies (optional)
  # config.strategies = [:ngram, :elasticsearch]
  # config.register_strategy(:elasticsearch, MyElasticsearchStrategy)
  # config.strategy_options[:elasticsearch] = { url: "http://localhost:9200" }
end
```

> **Note:** Changing `ngram_size` invalidates existing index entries. After changing it, run `RailsPanda::Search.reindex_search_all!` to rebuild.

## Usage

### Basic Setup

```ruby
class User < ApplicationRecord
  encrypts :email, :name

  can_search_in :email, :name
end
```

### Indexing Custom Methods

`can_search_in` accepts any method name, not just database columns. This is useful for indexing computed or derived values:

```ruby
class User < ApplicationRecord
  encrypts :first_name, :last_name

  can_search_in :first_name, :last_name, :full_name

  def full_name
    "#{first_name} #{last_name}"
  end
end
```

> **Note:** If the data backing a custom method changes through a path that doesn't trigger `after_save` on this model (e.g., a related model changes), call `record.reindex_search!` manually.

### Searching

```ruby
# Search across all indexed columns
User.search_for("alice")
# => #<ActiveRecord::Relation [#<User id: 1, ...>]>

# Search in specific columns only
User.search_for("example.com", columns: [:email])

# Chain with other scopes
User.where(active: true).search_for("alice")
```

### Global Search

Search across **all** models that use `can_search_in`:

```ruby
results = RailsPanda::Search.search_for("alice")
# => { "User" => #<ActiveRecord::Relation [...]>, "Contact" => #<ActiveRecord::Relation [...]> }
```

Column scoping is only available per-model via `User.search_for("alice", columns: [:email])`.

### Reindexing

```ruby
# Reindex a single record
user.reindex_search!

# Reindex all records in a model (clears all entries first)
User.reindex_search_all!

# Reindex all records across ALL searchable models
RailsPanda::Search.reindex_search_all!
```

### Large Dataset Reindexing

`reindex_search_all!` clears all entries before rebuilding, so if it's interrupted mid-way, unprocessed records lose their search entries. For large datasets where timeouts are a concern, use per-record reindexing instead:

```ruby
# Resumable batch reindex — safe to interrupt and pick up later
User.where("id > ?", last_processed_id).find_each(batch_size: 1000) do |record|
  record.reindex_search!
end
```

`reindex_search!` calls `sync_record!` per record (remove old entries + insert new ones), so existing entries for unprocessed records are preserved.

### Composite Primary Keys

The gem supports models with composite primary keys. Primary keys are stored as JSON:

```ruby
# Single PK: {"id": 1}
# Composite PK: {"tenant_id": 5, "id": 42}
```

## How It Works

The gem dispatches all indexing and searching operations to the active strategy classes. Each strategy implements `index_record!` (pure insert), `remove_record!`, `clear_for_source_type!`, and `search`. A default `sync_record!` (remove + index) is provided by the base class and can be overridden for incremental updates.

With the built-in **n-gram strategy**:

1. When a record is saved, its searchable columns are broken into n-grams (e.g., `"alice"` → `["ali", "lic", "ice"]`)
2. Each n-gram is stored in the `rails_panda_search_ngram_entries` table with a reference to the source record
3. When searching, the query string is also broken into n-grams
4. Records matching **all** query n-grams are found via `GROUP BY ... HAVING COUNT(DISTINCT ngram) = N`
5. The matching record IDs are used to build an `ActiveRecord::Relation`

## Custom Strategies

See [how_to_add_search_strategies.md](how_to_add_search_strategies.md) for a detailed guide on implementing your own strategy (Elasticsearch, Redis, remote API, etc.).

## Development

```bash
bundle install
bundle exec rake    # runs rspec + rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
