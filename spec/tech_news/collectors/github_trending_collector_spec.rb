# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Collectors::GithubTrendingCollector do
  let(:config) do
    double('Config',
           http_timeout: 10,
           max_articles_per_source: 5)
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }

  let(:sample_html) do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <body>
        <article class="Box-row">
          <h2>
            <a href="/user/repo1">user / repo1</a>
          </h2>
          <p class="col-9">A test repository description</p>
          <span itemprop="programmingLanguage">Ruby</span>
          <span class="d-inline-block float-sm-right">100 stars today</span>
        </article>
        <article class="Box-row">
          <h2>
            <a href="/user/repo2">user / repo2</a>
          </h2>
          <p class="col-9">Another test repository</p>
          <span itemprop="programmingLanguage">Python</span>
          <span class="d-inline-block float-sm-right">50 stars today</span>
        </article>
      </body>
      </html>
    HTML
  end

  describe '#initialize' do
    it 'creates collector without language' do
      collector = described_class.new(
        name: 'GitHub Trending',
        config: config,
        logger: logger
      )
      expect(collector.language).to be_nil
    end

    it 'creates collector with language' do
      collector = described_class.new(
        name: 'GitHub Trending',
        language: 'ruby',
        config: config,
        logger: logger
      )
      expect(collector.language).to eq('ruby')
    end
  end

  describe '#collect' do
    it 'fetches and parses trending repositories' do
      stub_request(:get, 'https://github.com/trending')
        .to_return(status: 200, body: sample_html)

      collector = described_class.new(
        name: 'GitHub Trending',
        config: config,
        logger: logger
      )

      articles = collector.collect
      expect(articles.length).to eq(2)
      expect(articles.first.title).to include('user / repo1')
      expect(articles.first.url).to eq('https://github.com/user/repo1')
      expect(articles.first.description).to eq('A test repository description')
    end

    it 'includes language in URL when specified' do
      stub_request(:get, 'https://github.com/trending/ruby')
        .to_return(status: 200, body: sample_html)

      collector = described_class.new(
        name: 'GitHub Trending Ruby',
        language: 'ruby',
        config: config,
        logger: logger
      )

      articles = collector.collect
      expect(articles.length).to eq(2)
    end

    it 'extracts metadata from repositories' do
      stub_request(:get, 'https://github.com/trending')
        .to_return(status: 200, body: sample_html)

      collector = described_class.new(
        name: 'GitHub Trending',
        config: config,
        logger: logger
      )

      articles = collector.collect
      first_article = articles.first
      expect(first_article.metadata[:language]).to eq('Ruby')
      expect(first_article.metadata[:stars_today]).to eq('100 stars today')
      expect(first_article.metadata[:repository]).to eq('user / repo1')
    end

    it 'limits articles based on config' do
      # Create HTML with many repositories
      many_repos = (1..10).map do |i|
        <<~REPO
          <article class="Box-row">
            <h2><a href="/user/repo#{i}">user / repo#{i}</a></h2>
            <p class="col-9">Repository #{i}</p>
          </article>
        REPO
      end.join

      large_html = "<html><body>#{many_repos}</body></html>"

      stub_request(:get, 'https://github.com/trending')
        .to_return(status: 200, body: large_html)

      collector = described_class.new(
        name: 'GitHub Trending',
        config: config,
        logger: logger
      )

      articles = collector.collect
      expect(articles.length).to eq(5) # limited by max_articles_per_source
    end
  end

  describe '#parse' do
    it 'handles empty HTML gracefully' do
      collector = described_class.new(
        name: 'GitHub Trending',
        config: config,
        logger: logger
      )

      articles = collector.parse('<html><body></body></html>')
      expect(articles).to be_empty
    end
  end
end
