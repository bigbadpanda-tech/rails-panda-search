$LOAD_PATH.push File.expand_path("lib", __dir__)

require "rails_panda_search/version"

Gem::Specification.new do |spec|
  spec.name = "rails-panda-search"
  spec.version = RailsPanda::Search::VERSION
  spec.authors = ["João Saraiva"]
  spec.email = ["panda@bigbadpanda.com"]

  spec.summary = "TODO: Write a short summary, because RubyGems requires one."
  spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "https://github.com/bigbadpanda-tech/rails-panda-search"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/develop/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "rails_panda_sensitive_data.gemspec",
    "Gemfile",
    # "Rakefile",
    "LICENSE",
    "CHANGELOG.md",
    "README.md"
  ]

  spec.add_dependency "rails", ">= 7.0.0"

  # spec.add_development_dependency "combustion"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "rubocop-rspec_rails"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "standard-rails"
  spec.add_development_dependency "sqlite3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
