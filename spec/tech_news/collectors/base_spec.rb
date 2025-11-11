# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Collectors::Base do
  let(:config) do
    double('Config',
           http_timeout: 10,
           max_articles_per_source: 5)
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }

  # Concrete implementation for testing
  class TestCollector < TechNews::Collectors::Base
    attr_accessor :fetch_result, :parse_result

    def fetch
      @fetch_result || 'test data'
    end

    def parse(_data)
      @parse_result || []
    end
  end

  describe '#collect' do
    it 'calls fetch and parse in sequence' do
      collector = TestCollector.new(name: 'Test', config: config, logger: logger)
      collector.parse_result = [
        TechNews::Models::Article.new(
          title: 'Test Article',
          url: 'https://example.com',
          source: 'Test'
        )
      ]

      articles = collector.collect
      expect(articles.length).to eq(1)
      expect(articles.first.title).to eq('Test Article')
    end

    it 'raises CollectorError on failure' do
      collector = TestCollector.new(name: 'Test', config: config, logger: logger)
      allow(collector).to receive(:fetch).and_raise(StandardError, 'Test error')

      expect do
        collector.collect
      end.to raise_error(TechNews::CollectorError, /Test error/)
    end
  end

  describe '#fetch' do
    it 'must be implemented by subclasses' do
      collector = described_class.new(name: 'Test', config: config, logger: logger)
      expect do
        collector.fetch
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#parse' do
    it 'must be implemented by subclasses' do
      collector = described_class.new(name: 'Test', config: config, logger: logger)
      expect do
        collector.parse('data')
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#fetch_url' do
    it 'fetches URL successfully' do
      stub_request(:get, 'https://example.com/test')
        .to_return(status: 200, body: 'content')

      collector = TestCollector.new(name: 'Test', config: config, logger: logger)
      result = collector.send(:fetch_url, 'https://example.com/test')
      expect(result).to eq('content')
    end

    it 'raises NetworkError on HTTP error' do
      stub_request(:get, 'https://example.com/error')
        .to_return(status: 404)

      collector = TestCollector.new(name: 'Test', config: config, logger: logger)
      expect do
        collector.send(:fetch_url, 'https://example.com/error')
      end.to raise_error(TechNews::NetworkError, /404/)
    end
  end

  describe '#limit_articles' do
    it 'limits articles to max_articles_per_source' do
      collector = TestCollector.new(name: 'Test', config: config, logger: logger)
      articles = (1..10).map do |i|
        TechNews::Models::Article.new(
          title: "Article #{i}",
          url: "https://example.com/#{i}",
          source: 'Test'
        )
      end

      limited = collector.send(:limit_articles, articles)
      expect(limited.length).to eq(5)
    end
  end
end
