# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Collectors::RssCollector do
  let(:config) do
    double('Config',
           http_timeout: 10,
           max_articles_per_source: 5)
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }

  let(:yesterday) do
    now = Time.new(2025, 1, 15, 12, 0, 0)
    now - 86_400 # 前日
  end

  let(:sample_rss) do
    <<~RSS
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <link>https://example.com</link>
          <description>Test RSS Feed</description>
          <item>
            <title>Test Article 1</title>
            <link>https://example.com/article1</link>
            <pubDate>#{yesterday.rfc2822}</pubDate>
            <description>This is a test article</description>
          </item>
          <item>
            <title>Test Article 2</title>
            <link>https://example.com/article2</link>
            <pubDate>#{(yesterday + 3600).rfc2822}</pubDate>
            <description><![CDATA[<p>Article with <strong>HTML</strong></p>]]></description>
          </item>
        </channel>
      </rss>
    RSS
  end

  describe '#initialize' do
    it 'creates RSS collector with valid URL' do
      collector = described_class.new(
        name: 'Test RSS',
        url: 'https://example.com/rss',
        config: config,
        logger: logger
      )
      expect(collector.url).to eq('https://example.com/rss')
    end

    it 'raises error with invalid URL' do
      expect do
        described_class.new(
          name: 'Test RSS',
          url: 'not-a-url',
          config: config,
          logger: logger
        )
      end.to raise_error(TechNews::ConfigurationError, /Invalid RSS URL/)
    end
  end

  describe '#collect' do
    before do
      # 時刻を固定して日付フィルタリングをテスト可能にする
      freeze_time = Time.new(2025, 1, 15, 12, 0, 0)
      allow(Time).to receive(:now).and_return(freeze_time)
    end

    it 'fetches and parses RSS feed' do
      stub_request(:get, 'https://example.com/rss')
        .to_return(status: 200, body: sample_rss)

      collector = described_class.new(
        name: 'Test RSS',
        url: 'https://example.com/rss',
        config: config,
        logger: logger
      )

      articles = collector.collect
      expect(articles.length).to eq(2)
      expect(articles.first.title).to eq('Test Article 1')
      expect(articles.first.url).to eq('https://example.com/article1')
      expect(articles.first.source).to eq('Test RSS')
    end

    it 'strips HTML from description' do
      stub_request(:get, 'https://example.com/rss')
        .to_return(status: 200, body: sample_rss)

      collector = described_class.new(
        name: 'Test RSS',
        url: 'https://example.com/rss',
        config: config,
        logger: logger
      )

      articles = collector.collect
      expect(articles.last.description).not_to include('<p>')
      expect(articles.last.description).not_to include('<strong>')
    end

    it 'limits articles based on config' do
      # Create RSS with 10 articles (all from yesterday)
      many_items = (1..10).map do |i|
        pub_date = (yesterday + (i * 600)).rfc2822 # 10分ずつずらす
        <<~ITEM
          <item>
            <title>Article #{i}</title>
            <link>https://example.com/article#{i}</link>
            <pubDate>#{pub_date}</pubDate>
          </item>
        ITEM
      end.join

      large_rss = <<~RSS
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Test Feed</title>
            #{many_items}
          </channel>
        </rss>
      RSS

      stub_request(:get, 'https://example.com/rss')
        .to_return(status: 200, body: large_rss)

      collector = described_class.new(
        name: 'Test RSS',
        url: 'https://example.com/rss',
        config: config,
        logger: logger
      )

      articles = collector.collect
      expect(articles.length).to eq(5) # limited by max_articles_per_source
    end
  end

  describe '#parse' do
    it 'raises ParseError on invalid RSS' do
      collector = described_class.new(
        name: 'Test RSS',
        url: 'https://example.com/rss',
        config: config,
        logger: logger
      )

      expect do
        collector.parse('invalid xml')
      end.to raise_error(TechNews::ParseError)
    end
  end
end
