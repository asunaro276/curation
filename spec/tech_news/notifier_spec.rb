# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TechNews::Notifier do
  let(:config) do
    double('Config',
      slack_post_interval: 1
    )
  end
  let(:logger) { TechNews::AppLogger.new(level: 'ERROR') }
  let(:webhook_url) { 'https://hooks.slack.com/services/T00/B00/XX' }

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
    it 'creates notifier with valid webhook URL' do
      notifier = described_class.new(
        webhook_url: webhook_url,
        config: config,
        logger: logger
      )
      expect(notifier.webhook_url).to eq(webhook_url)
    end

    it 'raises error with invalid webhook URL' do
      expect {
        described_class.new(
          webhook_url: 'http://example.com',
          config: config,
          logger: logger
        )
      }.to raise_error(TechNews::ConfigurationError, /Invalid Slack webhook/)
    end
  end

  describe '#notify' do
    it 'posts summary to Slack successfully' do
      stub_request(:post, webhook_url)
        .with(
          headers: { 'Content-Type' => 'application/json' },
          body: hash_including({ blocks: kind_of(Array) })
        )
        .to_return(status: 200, body: 'ok')

      notifier = described_class.new(
        webhook_url: webhook_url,
        config: config,
        logger: logger
      )

      expect { notifier.notify(summary) }.not_to raise_error
    end

    it 'includes article information in message' do
      posted_body = nil
      stub_request(:post, webhook_url)
        .to_return do |request|
          posted_body = JSON.parse(request.body)
          { status: 200, body: 'ok' }
        end

      notifier = described_class.new(
        webhook_url: webhook_url,
        config: config,
        logger: logger
      )

      notifier.notify(summary)

      expect(posted_body['blocks']).not_to be_empty
      # Check that the title is in the header
      header_block = posted_body['blocks'].find { |b| b['type'] == 'header' }
      expect(header_block['text']['text']).to eq('Test Article')
    end

    it 'handles rate limit errors' do
      stub_request(:post, webhook_url)
        .to_return(status: 429, body: 'rate limited')

      notifier = described_class.new(
        webhook_url: webhook_url,
        config: config,
        logger: logger
      )

      expect {
        notifier.notify(summary)
      }.to raise_error(TechNews::RateLimitError)
    end

    it 'retries on network errors' do
      call_count = 0
      stub_request(:post, webhook_url)
        .to_return do
          call_count += 1
          if call_count < 3
            raise Faraday::ConnectionFailed.new('Connection failed')
          else
            { status: 200, body: 'ok' }
          end
        end

      notifier = described_class.new(
        webhook_url: webhook_url,
        config: config,
        logger: logger
      )

      # Should eventually succeed after retries
      expect { notifier.notify(summary) }.not_to raise_error
      expect(call_count).to eq(3)
    end
  end

  describe '#notify_batch' do
    it 'posts multiple summaries with interval' do
      stub_request(:post, webhook_url)
        .to_return(status: 200, body: 'ok')

      notifier = described_class.new(
        webhook_url: webhook_url,
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
      stub_request(:post, webhook_url)
        .to_return do
          call_count += 1
          if call_count == 2
            { status: 500, body: 'error' }
          else
            { status: 200, body: 'ok' }
          end
        end

      notifier = described_class.new(
        webhook_url: webhook_url,
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
