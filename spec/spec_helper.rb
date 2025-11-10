# frozen_string_literal: true

require 'bundler/setup'
require 'webmock/rspec'
require 'dotenv/load'

# Disable real HTTP requests in tests
WebMock.disable_net_connect!(allow_localhost: true)

# Load all lib files
Dir[File.join(__dir__, '../lib/**/*.rb')].sort.each { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean up test artifacts after each test
  config.before(:each) do
    # Reset environment variables for tests
    ENV['ANTHROPIC_API_KEY'] ||= 'test_key'
    ENV['SLACK_WEBHOOK_URL'] ||= 'https://hooks.slack.com/test'
  end
end
