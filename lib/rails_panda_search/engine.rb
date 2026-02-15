# frozen_string_literal: true

module RailsPanda
  module Search
    class Engine < ::Rails::Engine
      isolate_namespace RailsPanda::Search

      initializer "rails_panda_search.append_migrations" do |app|
        # :nocov:
        unless app.root.to_s.match?(root.to_s)
          RailsPanda::Search.config.strategies.each do |strategy|
            path = root.join("db", "migrate", "strategies", strategy.to_s)
            app.config.paths["db/migrate"] << path.to_s if path.exist?
          end
        end
        # :nocov:
      end

      initializer "rails_panda_search.check_ngram_size" do
        ActiveSupport.on_load(:active_record) do
          if RailsPanda::Search.config.strategy_enabled?(:ngram) &&
              RailsPanda::Search::Strategies::Ngram::NgramEntry.table_exists?
            sample = RailsPanda::Search::Strategies::Ngram::NgramEntry.first
            if sample && sample.ngram.length != RailsPanda::Search.config.ngram_size
              Rails.logger.warn(
                "[rails-panda-search] WARNING: Existing n-gram entries have length " \
                "#{sample.ngram.length} but configured ngram_size is " \
                "#{RailsPanda::Search.config.ngram_size}. " \
                "Run RailsPanda::Search.reindex_search_all! to rebuild the index."
              )
            end
          end
        rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
          # Database not yet created or table doesn't exist — skip check
        end
      end
    end
  end
end
