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

  describe '#calculate_yesterday_range' do
    it 'returns the start and end time of yesterday' do
      freeze_time = Time.new(2025, 1, 15, 12, 0, 0)
      allow(Time).to receive(:now).and_return(freeze_time)

      collector = TestCollector.new(name: 'Test', config: config, logger: logger)
      start_time, end_time = collector.send(:calculate_yesterday_range)

      expect(start_time).to eq(Time.new(2025, 1, 14, 0, 0, 0))
      expect(end_time).to eq(Time.new(2025, 1, 14, 23, 59, 59))
    end
  end

  describe '#filter_by_date' do
    let(:collector) { TestCollector.new(name: 'Test', config: config, logger: logger) }
    let(:freeze_time) { Time.new(2025, 1, 15, 12, 0, 0) }

    before do
      allow(Time).to receive(:now).and_return(freeze_time)
    end

    it 'includes articles published within yesterday\'s date range' do
      articles = [
        TechNews::Models::Article.new(
          title: 'Article in range',
          url: 'https://example.com/1',
          published_at: Time.new(2025, 1, 14, 12, 0, 0),
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(1)
      expect(filtered.first.title).to eq('Article in range')
    end

    it 'excludes articles published before yesterday' do
      articles = [
        TechNews::Models::Article.new(
          title: 'Old article',
          url: 'https://example.com/1',
          published_at: Time.new(2025, 1, 13, 23, 59, 59),
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(0)
    end

    it 'excludes articles published after yesterday' do
      articles = [
        TechNews::Models::Article.new(
          title: 'Future article',
          url: 'https://example.com/1',
          published_at: Time.new(2025, 1, 15, 0, 0, 0),
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(0)
    end

    it 'includes articles at the start boundary (00:00:00)' do
      articles = [
        TechNews::Models::Article.new(
          title: 'Start boundary article',
          url: 'https://example.com/1',
          published_at: Time.new(2025, 1, 14, 0, 0, 0),
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(1)
    end

    it 'includes articles at the end boundary (23:59:59)' do
      articles = [
        TechNews::Models::Article.new(
          title: 'End boundary article',
          url: 'https://example.com/1',
          published_at: Time.new(2025, 1, 14, 23, 59, 59),
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(1)
    end

    it 'excludes articles with nil published_at' do
      articles = [
        TechNews::Models::Article.new(
          title: 'Article without date',
          url: 'https://example.com/1',
          published_at: nil,
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(0)
    end

    it 'filters mixed articles correctly' do
      articles = [
        TechNews::Models::Article.new(
          title: 'Valid article 1',
          url: 'https://example.com/1',
          published_at: Time.new(2025, 1, 14, 8, 0, 0),
          source: 'Test'
        ),
        TechNews::Models::Article.new(
          title: 'Old article',
          url: 'https://example.com/2',
          published_at: Time.new(2025, 1, 13, 12, 0, 0),
          source: 'Test'
        ),
        TechNews::Models::Article.new(
          title: 'Valid article 2',
          url: 'https://example.com/3',
          published_at: Time.new(2025, 1, 14, 20, 0, 0),
          source: 'Test'
        ),
        TechNews::Models::Article.new(
          title: 'Article without date',
          url: 'https://example.com/4',
          published_at: nil,
          source: 'Test'
        ),
        TechNews::Models::Article.new(
          title: 'Future article',
          url: 'https://example.com/5',
          published_at: Time.new(2025, 1, 15, 1, 0, 0),
          source: 'Test'
        )
      ]

      filtered = collector.send(:filter_by_date, articles)
      expect(filtered.length).to eq(2)
      expect(filtered.map(&:title)).to contain_exactly('Valid article 1', 'Valid article 2')
    end
  end
end
