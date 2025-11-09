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

    it 'raises error when SLACK_WEBHOOK_URL is missing' do
      ENV['SLACK_WEBHOOK_URL'] = ''
      expect {
        TechNews::Config.new(config_path: config_file.path)
      }.to raise_error(TechNews::Config::ConfigurationError, /SLACK_WEBHOOK_URL/)
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
