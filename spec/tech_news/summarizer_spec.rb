# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Summarizer do
  let(:config) do
    double('Config',
           claude_model: 'claude-3-5-sonnet-20241022',
           max_content_tokens: 4000,
           api_timeout: 30,
           summarization_template: 'default')
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
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)

      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )
      expect(summarizer.api_key).to eq(api_key)
      expect(summarizer.model).to eq('claude-3-5-sonnet-20241022')
      expect(summarizer.template[:name]).to eq('default')
    end

    it 'allows custom model override' do
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)

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
      # Mock the Anthropic client before initialization
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_return(mock_api_response)

      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      result = summarizer.summarize(article)

      expect(result[:article]).to eq(article)
      expect(result[:summary]).to include('要約')
      expect(result[:summary]).to include('重要なポイント')
      expect(result[:model]).to eq('claude-3-5-sonnet-20241022')
    end

    it 'raises SummarizerError on API failure' do
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_raise(Faraday::Error.new('API error'))

      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      expect do
        summarizer.summarize(article)
      end.to raise_error(TechNews::SummarizerError)
    end

    it 'handles rate limit errors' do
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_raise(Faraday::TooManyRequestsError.new('Rate limited'))

      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      expect do
        summarizer.summarize(article)
      end.to raise_error(TechNews::RateLimitError)
    end
  end

  describe '#truncate_content' do
    it 'truncates long content' do
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)

      summarizer = described_class.new(
        api_key: api_key,
        config: config,
        logger: logger
      )

      long_text = 'a' * 20_000
      truncated = summarizer.send(:truncate_content, long_text, max_tokens: 1000)

      expect(truncated.length).to be < long_text.length
      expect(truncated).to end_with('...')
    end

    it 'does not truncate short content' do
      client = double('Anthropic::Client')
      allow(Anthropic::Client).to receive(:new).and_return(client)

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
