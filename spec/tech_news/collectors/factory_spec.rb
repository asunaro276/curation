# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Collectors::Factory do
  let(:config) do
    double('Config',
      http_timeout: 10,
      max_articles_per_source: 5,
      enabled_sources: [
        { 'type' => 'rss', 'name' => 'Test RSS', 'url' => 'https://example.com/rss', 'enabled' => true },
        { 'type' => 'github_trending', 'name' => 'GitHub', 'language' => 'ruby', 'enabled' => true }
      ]
    )
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }

  describe '.create_from_config' do
    it 'creates RSS collector' do
      source_config = { 'type' => 'rss', 'name' => 'Test RSS', 'url' => 'https://example.com/rss' }
      collector = described_class.create_from_config(source_config, config, logger)

      expect(collector).to be_a(TechNews::Collectors::RssCollector)
      expect(collector.name).to eq('Test RSS')
      expect(collector.url).to eq('https://example.com/rss')
    end

    it 'creates GitHub Trending collector' do
      source_config = { 'type' => 'github_trending', 'name' => 'GitHub', 'language' => 'ruby' }
      collector = described_class.create_from_config(source_config, config, logger)

      expect(collector).to be_a(TechNews::Collectors::GithubTrendingCollector)
      expect(collector.name).to eq('GitHub')
      expect(collector.language).to eq('ruby')
    end

    it 'raises error for unsupported type' do
      source_config = { 'type' => 'unsupported', 'name' => 'Test' }

      expect {
        described_class.create_from_config(source_config, config, logger)
      }.to raise_error(TechNews::ConfigurationError, /Unsupported collector type/)
    end

    it 'raises error for RSS collector without URL' do
      source_config = { 'type' => 'rss', 'name' => 'Test RSS' }

      expect {
        described_class.create_from_config(source_config, config, logger)
      }.to raise_error(TechNews::ConfigurationError, /requires 'url'/)
    end
  end

  describe '.create_all_from_config' do
    it 'creates all collectors from config' do
      collectors = described_class.create_all_from_config(config, logger)

      expect(collectors.length).to eq(2)
      expect(collectors[0]).to be_a(TechNews::Collectors::RssCollector)
      expect(collectors[1]).to be_a(TechNews::Collectors::GithubTrendingCollector)
    end

    it 'skips invalid collectors and continues' do
      bad_config = double('Config',
        enabled_sources: [
          { 'type' => 'rss', 'name' => 'Good RSS', 'url' => 'https://example.com/rss' },
          { 'type' => 'invalid', 'name' => 'Bad' },
          { 'type' => 'rss', 'name' => 'Another Good', 'url' => 'https://example.com/rss2' }
        ],
        http_timeout: 10,
        max_articles_per_source: 5
      )

      collectors = described_class.create_all_from_config(bad_config, logger)

      expect(collectors.length).to eq(2) # Only the valid ones
      expect(collectors.all? { |c| c.is_a?(TechNews::Collectors::RssCollector) }).to be true
    end
  end
end
