# Changelog

## [Unreleased]

## [1.0.1] - 2026-03-07

### Added

- **Configurable n-gram table name** via `config.ngram_entries_table_name`, with default `rails_panda_search_ngram_entries`

### Changed

- **NgramEntry** now reads its table name from configuration, allowing host apps to override the storage table
- **N-gram migration** uses the configured table name for `create_table`/`add_index` while keeping a stable, short index name

## [1.0.0] - 2026-02-15

### Added

- **Pluggable strategy interface** — abstract `Strategies::Base` class with 4 abstract methods (`index_record!`, `remove_record!`, `clear_for_source_type!`, `search`) and a default `sync_record!` (remove + index, overridable)
- **Strategy registry** — `config.register_strategy` for runtime registration of custom strategies
- **Strategy-specific options** — `config.strategy_options` hash for per-strategy configuration
- **Multiple concurrent strategies** — all active strategies are dispatched in parallel
- **N-gram search strategy** — configurable n-gram size (default: trigrams)
- **`can_search_in` DSL** — declare searchable columns (or methods) on any ActiveRecord model
- **`search_for` scope** — chainable ActiveRecord relation for substring matching, with optional column scoping
- **Global search** — `RailsPanda::Search.search_for` searches across all searchable models
- **`reindex_search!`** — instance method for per-record index sync (safe for large datasets)
- **`reindex_search_all!`** — class method for bulk reindexing (per-model or global)
- **Composite primary key support** — via JSON `source_id` column
- **Strategy-gated migrations** — Engine loads only migrations for enabled strategies
- **Rails Engine** — auto-appends migrations to host app
- **N-gram size mismatch warning** — logs a warning on boot if existing entries don't match configured `ngram_size`
- **Developer guide** — `how_to_add_search_strategies.md` for implementing custom strategies
