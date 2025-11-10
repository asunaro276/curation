# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/tech_news/notifiers/line_notifier'
require_relative '../../../lib/tech_news/config'
require_relative '../../../lib/tech_news/logger'
require_relative '../../../lib/tech_news/errors'
require_relative '../../../lib/tech_news/models/article'

RSpec.describe TechNews::Notifiers::LineNotifier do
  let(:config) do
    double('Config',
      enabled_notifiers: ['line']
    )
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }
  let(:channel_access_token) { 'test_channel_access_token' }
  let(:target_id) { 'U123456' }

  let(:article) do
    TechNews::Models::Article.new(
      title: 'Test Article',
      url: 'https://example.com/article',
      source: 'Test Source',
      description: 'Test description'
    )
  end

  let(:summary) do
    {
      article: article,
      summary: "要約テキスト\n\n重要なポイント:\n- ポイント1\n- ポイント2",
      model: 'claude-3-5-sonnet-20241022',
      timestamp: Time.now
    }
  end

  describe '#initialize' do
    it 'creates notifier with valid credentials' do
      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )
      expect(notifier.channel_access_token).to eq(channel_access_token)
      expect(notifier.target_id).to eq(target_id)
    end

    it 'raises error with missing channel access token' do
      expect {
        described_class.new(
          channel_access_token: '',
          target_id: target_id,
          config: config,
          logger: logger
        )
      }.to raise_error(TechNews::ConfigurationError, /Channel Access Token/)
    end

    it 'raises error with missing target ID' do
      expect {
        described_class.new(
          channel_access_token: channel_access_token,
          target_id: '',
          config: config,
          logger: logger
        )
      }.to raise_error(TechNews::ConfigurationError, /Target ID/)
    end
  end

  describe '#notify' do
    let(:line_api_url) { 'https://api.line.me/v2/bot/message/push' }

    it 'posts summary to LINE successfully' do
      stub_request(:post, line_api_url)
        .with(
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{channel_access_token}"
          },
          body: hash_including({ to: target_id, messages: kind_of(Array) })
        )
        .to_return(status: 200, body: '{}')

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      expect { notifier.notify(summary) }.not_to raise_error
    end

    it 'sends Flex Message format' do
      posted_body = nil
      stub_request(:post, line_api_url)
        .to_return do |request|
          posted_body = JSON.parse(request.body)
          { status: 200, body: '{}' }
        end

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      notifier.notify(summary)

      expect(posted_body['messages']).not_to be_empty
      message = posted_body['messages'].first
      expect(message['type']).to eq('flex')
      expect(message['contents']['type']).to eq('bubble')
    end

    it 'includes article information in Flex Message' do
      posted_body = nil
      stub_request(:post, line_api_url)
        .to_return do |request|
          posted_body = JSON.parse(request.body)
          { status: 200, body: '{}' }
        end

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      notifier.notify(summary)

      flex_contents = posted_body['messages'].first['contents']

      # Check header contains title
      header_text = flex_contents['header']['contents'].first['text']
      expect(header_text).to eq('Test Article')

      # Check footer contains button with URL
      button = flex_contents['footer']['contents'].first
      expect(button['action']['uri']).to eq(article.url)
    end

    it 'truncates long titles' do
      long_article = TechNews::Models::Article.new(
        title: 'A' * 200,
        url: 'https://example.com/article',
        source: 'Test Source',
        description: 'Test'
      )
      long_summary = { article: long_article, summary: 'Summary', model: 'test', timestamp: Time.now }

      posted_body = nil
      stub_request(:post, line_api_url)
        .to_return do |request|
          posted_body = JSON.parse(request.body)
          { status: 200, body: '{}' }
        end

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      notifier.notify(long_summary)

      flex_contents = posted_body['messages'].first['contents']
      header_text = flex_contents['header']['contents'].first['text']
      expect(header_text.length).to be <= 100
      expect(header_text).to end_with('...')
    end

    it 'handles rate limit errors' do
      stub_request(:post, line_api_url)
        .to_return(status: 429, body: '{"message":"Rate limit exceeded"}')

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      expect {
        notifier.notify(summary)
      }.to raise_error(TechNews::RateLimitError)
    end

    it 'retries on network errors' do
      call_count = 0
      stub_request(:post, line_api_url)
        .to_return do
          call_count += 1
          if call_count < 3
            raise Faraday::ConnectionFailed.new('Connection failed')
          else
            { status: 200, body: '{}' }
          end
        end

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      # Should eventually succeed after retries
      expect { notifier.notify(summary) }.not_to raise_error
      expect(call_count).to eq(3)
    end

    it 'handles authentication errors' do
      stub_request(:post, line_api_url)
        .to_return(status: 401, body: '{"message":"Invalid credentials"}')

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      expect {
        notifier.notify(summary)
      }.to raise_error(TechNews::WebhookError, /401/)
    end
  end

  describe '#notify_batch' do
    let(:line_api_url) { 'https://api.line.me/v2/bot/message/push' }

    it 'posts multiple summaries with interval' do
      stub_request(:post, line_api_url)
        .to_return(status: 200, body: '{}')

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      summaries = [summary, summary]
      result = notifier.notify_batch(summaries, wait_interval: 0.1)

      expect(result[:posted]).to eq(2)
      expect(result[:failed]).to eq(0)
    end

    it 'continues on partial failures' do
      call_count = 0
      stub_request(:post, line_api_url)
        .to_return do
          call_count += 1
          if call_count == 2
            { status: 500, body: '{"message":"Server error"}' }
          else
            { status: 200, body: '{}' }
          end
        end

      notifier = described_class.new(
        channel_access_token: channel_access_token,
        target_id: target_id,
        config: config,
        logger: logger
      )

      summaries = [summary, summary, summary]
      result = notifier.notify_batch(summaries, wait_interval: 0.1)

      expect(result[:posted]).to eq(2)
      expect(result[:failed]).to eq(1)
    end
  end
end
