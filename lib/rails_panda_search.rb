# frozen_string_literal: true

require "rails_panda_search/search"
# :nocov:
require "rails_panda_search/engine" if defined?(Rails)
# :nocov:
require "rails_panda_search/strategies/base"
require "rails_panda_search/strategies/ngram/ngram_entry"
require "rails_panda_search/strategies/ngram/ngram_indexer"
require "rails_panda_search/strategies/ngram/ngram_strategy"
require "rails_panda_search/searchable"

module RailsPanda
  module Search
  end
end
