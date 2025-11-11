# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 3.0.0"

gem "ruby-anthropic", "~> 0.4.2"        # Claude API client
gem "faraday", "~> 2.7"           # HTTP client
gem "faraday-retry", "~> 2.2"    # HTTP retry middleware
gem "faraday-follow_redirects", "~> 0.3.0"  # HTTP redirect following
gem "nokogiri", "~> 1.15"         # HTML/XML parsing
gem "rss"                         # RSS feed parsing

group :development, :test do
  gem "rspec", "~> 3.12"          # Testing framework
  gem "webmock", "~> 3.18"        # HTTP request stubbing
  gem "dotenv", "~> 2.8"          # Environment variable management
  gem "rubocop", "~> 1.56"        # Code style checker
end
