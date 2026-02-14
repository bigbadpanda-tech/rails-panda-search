# frozen_string_literal: true

module RailsPanda
  module Search
    class Config # rubocop:disable Lint/EmptyClass
    end

    class << self
      def configure
        yield config
      end

      def config
        @config ||= Config.new
      end
    end
  end
end
