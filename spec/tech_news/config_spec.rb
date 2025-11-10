# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe TechNews::Config do
  let(:valid_config) do
    {
      'sources' => [
        { 'type' => 'rss', 'name' => 'Test RSS', 'url' => 'https://example.com/rss', 'enabled' => true }
      ],
      'limits' => { 'max_articles_per_source' => 5 },
      'slack' => { 'post_interval' => 1 }
    }
  end

  let(:config_file) do
    file = Tempfile.new(['sources', '.yml'])
    file.write(YAML.dump(valid_config))
    file.rewind
    file
  end

  before do
    ENV['ANTHROPIC_API_KEY'] = 'test_api_key'
    ENV['SLACK_WEBHOOK_URL'] = 'https://hooks.slack.com/test'
    ENV['ENABLED_NOTIFIERS'] = 'slack'  # Default to slack for backward compatibility
    ENV.delete('LINE_CHANNEL_ACCESS_TOKEN')
    ENV.delete('LINE_USER_ID')
    ENV.delete('LINE_GROUP_ID')
  end

  after do
    config_file.close
    config_file.unlink
  end

  describe '#initialize' do
    it 'loads configuration from file' do
      config = TechNews::Config.new(config_path: config_file.path)
      expect(config.sources).to eq(valid_config['sources'])
    end

    it 'loads environment variables' do
      config = TechNews::Config.new(config_path: config_file.path)
      expect(config.anthropic_api_key).to eq('test_api_key')
      expect(config.slack_webhook_url).to eq('https://hooks.slack.com/test')
    end

    it 'raises error when config file not found' do
      expect {
        TechNews::Config.new(config_path: 'nonexistent.yml')
      }.to raise_error(TechNews::Config::ConfigurationError, /not found/)
    end

    it 'raises error when ANTHROPIC_API_KEY is missing' do
      ENV['ANTHROPIC_API_KEY'] = ''
      expect {
        TechNews::Config.new(config_path: config_file.path)
      }.to raise_error(TechNews::Config::ConfigurationError, /ANTHROPIC_API_KEY/)
    end

    it 'raises error when SLACK_WEBHOOK_URL is missing and Slack is enabled' do
      ENV['SLACK_WEBHOOK_URL'] = ''
      ENV['ENABLED_NOTIFIERS'] = 'slack'
      expect {
        TechNews::Config.new(config_path: config_file.path)
      }.to raise_error(TechNews::Config::ConfigurationError, /SLACK_WEBHOOK_URL/)
    end

    it 'loads LINE configuration when provided' do
      ENV['LINE_CHANNEL_ACCESS_TOKEN'] = 'test_line_token'
      ENV['LINE_USER_ID'] = 'U123456'
      ENV['ENABLED_NOTIFIERS'] = 'line'
      ENV['SLACK_WEBHOOK_URL'] = ''  # Not required when only LINE is enabled

      config = TechNews::Config.new(config_path: config_file.path)
      expect(config.line_channel_access_token).to eq('test_line_token')
      expect(config.line_target_id).to eq('U123456')
      expect(config.enabled_notifiers).to eq(['line'])
    end

    it 'raises error when LINE_CHANNEL_ACCESS_TOKEN is missing and LINE is enabled' do
      ENV['ENABLED_NOTIFIERS'] = 'line'
      ENV['SLACK_WEBHOOK_URL'] = ''
      expect {
        TechNews::Config.new(config_path: config_file.path)
      }.to raise_error(TechNews::Config::ConfigurationError, /LINE_CHANNEL_ACCESS_TOKEN/)
    end

    it 'raises error when LINE_USER_ID/LINE_GROUP_ID is missing and LINE is enabled' do
      ENV['ENABLED_NOTIFIERS'] = 'line'
      ENV['LINE_CHANNEL_ACCESS_TOKEN'] = 'test_line_token'
      ENV['SLACK_WEBHOOK_URL'] = ''
      expect {
        TechNews::Config.new(config_path: config_file.path)
      }.to raise_error(TechNews::Config::ConfigurationError, /LINE_USER_ID or LINE_GROUP_ID/)
    end

    it 'supports multiple notifiers' do
      ENV['LINE_CHANNEL_ACCESS_TOKEN'] = 'test_line_token'
      ENV['LINE_USER_ID'] = 'U123456'
      ENV['ENABLED_NOTIFIERS'] = 'slack,line'

      config = TechNews::Config.new(config_path: config_file.path)
      expect(config.enabled_notifiers).to eq(['slack', 'line'])
    end

    it 'defaults to slack when ENABLED_NOTIFIERS is not set' do
      ENV.delete('ENABLED_NOTIFIERS')
      config = TechNews::Config.new(config_path: config_file.path)
      expect(config.enabled_notifiers).to eq(['slack'])
    end
  end

  describe '#enabled_sources' do
    it 'returns only enabled sources' do
      config = TechNews::Config.new(config_path: config_file.path)
      expect(config.enabled_sources.length).to eq(1)
      expect(config.enabled_sources.first['enabled']).to be true
    end
  end

  describe 'accessor methods' do
    let(:config) { TechNews::Config.new(config_path: config_file.path) }

    it 'returns max_articles_per_source' do
      expect(config.max_articles_per_source).to eq(5)
    end

    it 'returns default max_content_tokens' do
      expect(config.max_content_tokens).to eq(4000)
    end

    it 'returns slack_post_interval' do
      expect(config.slack_post_interval).to eq(1)
    end
  end
end
