# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/tech_news/notifiers/slack_notifier'
require_relative '../../../lib/tech_news/config'
require_relative '../../../lib/tech_news/logger'
require_relative '../../../lib/tech_news/errors'
require_relative '../../../lib/tech_news/models/article'

RSpec.describe TechNews::Notifiers::SlackNotifier do
  let(:config) do
    double('Config',
           slack_post_interval: 1)
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
      expect do
        described_class.new(
          webhook_url: 'http://example.com',
          config: config,
          logger: logger
        )
      end.to raise_error(TechNews::ConfigurationError, /Invalid Slack webhook/)
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

      expect do
        notifier.notify(summary)
      end.to raise_error(TechNews::RateLimitError)
    end

    it 'retries on network errors' do
      call_count = 0
      stub_request(:post, webhook_url)
        .to_return do
          call_count += 1
          raise Faraday::ConnectionFailed.new('Connection failed') if call_count < 3

          { status: 200, body: 'ok' }
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
    context 'with consolidated mode (default)' do
      it 'posts multiple summaries as one consolidated message' do
        stub_request(:post, webhook_url)
          .to_return(status: 200, body: 'ok')

        notifier = described_class.new(
          webhook_url: webhook_url,
          config: config,
          logger: logger
        )

        article2 = TechNews::Models::Article.new(
          title: 'Test Article 2',
          url: 'https://example.com/article2',
          source: 'Test Source 2',
          description: 'Test description 2'
        )

        summary2 = {
          article: article2,
          summary: "要約テキスト2\n\n重要なポイント:\n- ポイント1\n- ポイント2",
          model: 'claude-3-5-sonnet-20241022',
          timestamp: Time.now
        }

        summaries = [summary, summary2]
        result = notifier.notify_batch(summaries)

        expect(result[:posted]).to eq(2)
        expect(result[:failed]).to eq(0)

        # 1回のPOSTリクエストのみ送信されることを確認
        expect(WebMock).to have_requested(:post, webhook_url).once
      end

      it 'includes article count in header' do
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

        summaries = [summary, summary]
        notifier.notify_batch(summaries)

        header_block = posted_body['blocks'].find { |b| b['type'] == 'header' }
        expect(header_block['text']['text']).to include('2件')
      end

      it 'includes dividers between articles' do
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

        summaries = [summary, summary]
        notifier.notify_batch(summaries)

        divider_blocks = posted_body['blocks'].select { |b| b['type'] == 'divider' }
        expect(divider_blocks.length).to eq(1) # 2記事なので区切り線は1つ
      end

      it 'skips empty summaries' do
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

        empty_summary = {
          article: article,
          summary: '',
          model: 'claude-3-5-sonnet-20241022',
          timestamp: Time.now
        }

        summaries = [summary, empty_summary]
        notifier.notify_batch(summaries)

        header_block = posted_body['blocks'].find { |b| b['type'] == 'header' }
        expect(header_block['text']['text']).to include('1件') # 空の要約はカウントしない
      end

      it 'validates message size' do
        stub_request(:post, webhook_url)
          .to_return(status: 200, body: 'ok')

        notifier = described_class.new(
          webhook_url: webhook_url,
          config: config,
          logger: logger
        )

        # 非常に長い要約を作成してサイズ制限をテスト
        large_summary = {
          article: article,
          summary: 'x' * 40_000, # 40,000文字
          model: 'claude-3-5-sonnet-20241022',
          timestamp: Time.now
        }

        summaries = [large_summary]

        expect do
          notifier.notify_batch(summaries)
        end.to raise_error(TechNews::WebhookError, /メッセージサイズが制限/)
      end
    end

    context 'with individual mode' do
      it 'posts multiple summaries with interval' do
        stub_request(:post, webhook_url)
          .to_return(status: 200, body: 'ok')

        notifier = described_class.new(
          webhook_url: webhook_url,
          config: config,
          logger: logger
        )

        summaries = [summary, summary]
        result = notifier.notify_batch(summaries, wait_interval: 0.1, consolidated: false)

        expect(result[:posted]).to eq(2)
        expect(result[:failed]).to eq(0)

        # 2回のPOSTリクエストが送信されることを確認
        expect(WebMock).to have_requested(:post, webhook_url).twice
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
        result = notifier.notify_batch(summaries, wait_interval: 0.1, consolidated: false)

        expect(result[:posted]).to eq(2)
        expect(result[:failed]).to eq(1)
      end
    end
  end
end
