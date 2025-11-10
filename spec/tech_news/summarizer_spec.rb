# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Summarizer do
  let(:config) do
    double('Config',
      claude_model: 'claude-3-5-sonnet-20241022',
      max_content_tokens: 4000,
      api_timeout: 30
    )
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }
  let(:api_key) { 'test_api_key' }

  let(:article) do
    TechNews::Models::Article.new(
      title: 'Test Article',
      url: 'https://example.com/article',
      source: 'Test Source',
      description: 'This is a test article about Ruby programming.'
    )
  end

  let(:mock_api_response) do
    {
      'content' => [
        {
          'type' => 'text',
          'text' => "要約: Rubyプログラミングに関する記事です。\n\n重要なポイント:\n- ポイント1\n- ポイント2\n- ポイント3"
        }
      ]
    }
  end

  describe '#initialize' do
    it 'creates summarizer with API key' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )
      expect(summarizer.api_key).to eq(api_key)
      expect(summarizer.model).to eq('claude-3-5-sonnet-20241022')
    end

    it 'allows custom model override' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger,
        model: 'custom-model'
      )
      expect(summarizer.model).to eq('custom-model')
    end
  end

  describe '#summarize' do
    it 'summarizes article successfully' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      # Mock the Anthropic client
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_return(mock_api_response)

      result = summarizer.summarize(article)

      expect(result[:article]).to eq(article)
      expect(result[:summary]).to include('要約')
      expect(result[:summary]).to include('重要なポイント')
      expect(result[:model]).to eq('claude-3-5-sonnet-20241022')
    end

    it 'raises SummarizerError on API failure' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_raise(Faraday::Error.new('API error'))

      expect {
        summarizer.summarize(article)
      }.to raise_error(TechNews::SummarizerError)
    end

    it 'handles rate limit errors' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_raise(Faraday::TooManyRequestsError.new('Rate limited'))

      expect {
        summarizer.summarize(article)
      }.to raise_error(TechNews::RateLimitError)
    end
  end

  describe '#truncate_content' do
    it 'truncates long content' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      long_text = 'a' * 20000
      truncated = summarizer.send(:truncate_content, long_text, max_tokens: 1000)

      expect(truncated.length).to be < long_text.length
      expect(truncated).to end_with('...')
    end

    it 'does not truncate short content' do
      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      short_text = 'Short text'
      result = summarizer.send(:truncate_content, short_text, max_tokens: 1000)

      expect(result).to eq(short_text)
    end
  end
end
