# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/tech_news/notifiers/base'
require_relative '../../../lib/tech_news/config'
require_relative '../../../lib/tech_news/logger'
require_relative '../../../lib/tech_news/errors'

RSpec.describe TechNews::Notifiers::Base do
  let(:config) { instance_double(TechNews::Config) }
  let(:logger) { instance_double(TechNews::AppLogger) }

  # Create a concrete implementation for testing the abstract class
  let(:concrete_notifier_class) do
    Class.new(described_class) do
      def notify(summary)
        # Simple implementation for testing
        logger.info("Notifying: #{summary[:article].title}")
      end

      protected

      def validate_configuration!
        # No validation needed for test
      end
    end
  end

  subject(:notifier) { concrete_notifier_class.new(config: config, logger: logger) }

  describe '#initialize' do
    it 'sets config and logger' do
      expect(notifier.config).to eq(config)
      expect(notifier.logger).to eq(logger)
    end

    it 'calls validate_configuration!' do
      notifier_class_with_validation = Class.new(described_class) do
        def validate_configuration!
          raise StandardError, 'Validation called'
        end
      end

      expect do
        notifier_class_with_validation.new(config: config, logger: logger)
      end.to raise_error(StandardError, 'Validation called')
    end
  end

  describe '#notify' do
    it 'raises NotImplementedError for base class' do
      base_notifier = described_class.allocate
      expect { base_notifier.notify({}) }.to raise_error(NotImplementedError)
    end
  end

  describe '#notify_batch' do
    let(:article1) { instance_double(TechNews::Models::Article, title: 'Article 1') }
    let(:article2) { instance_double(TechNews::Models::Article, title: 'Article 2') }
    let(:summaries) do
      [
        { article: article1, summary: 'Summary 1' },
        { article: article2, summary: 'Summary 2' }
      ]
    end

    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:error)
    end

    it 'processes all summaries successfully' do
      allow(notifier).to receive(:notify).and_return(true)
      allow(notifier).to receive(:sleep) # Stub sleep to speed up tests

      result = notifier.notify_batch(summaries, wait_interval: 0.01)

      expect(result).to eq(posted: 2, failed: 0)
      expect(notifier).to have_received(:notify).twice
    end

    it 'continues processing after a failure' do
      call_count = 0
      allow(notifier).to receive(:notify) do
        call_count += 1
        raise StandardError, 'API error' if call_count == 1

        true
      end
      allow(notifier).to receive(:sleep)

      result = notifier.notify_batch(summaries, wait_interval: 0.01)

      expect(result).to eq(posted: 1, failed: 1)
    end

    it 'logs batch progress' do
      allow(notifier).to receive(:notify).and_return(true)
      allow(notifier).to receive(:sleep)

      notifier.notify_batch(summaries, wait_interval: 0.01)

      expect(logger).to have_received(:info).with(/Starting batch notification/)
      expect(logger).to have_received(:info).with(/Batch notification complete/)
    end

    it 'waits between posts' do
      allow(notifier).to receive(:notify).and_return(true)
      allow(notifier).to receive(:sleep)

      notifier.notify_batch(summaries, wait_interval: 1.5)

      # Should sleep once (not after the last post)
      expect(notifier).to have_received(:sleep).with(1.5).once
    end
  end

  describe '#truncate_text' do
    it 'returns text as-is if within limit' do
      text = 'Short text'
      expect(notifier.send(:truncate_text, text, 20)).to eq(text)
    end

    it 'truncates long text with ellipsis' do
      text = 'This is a very long text that needs to be truncated'
      result = notifier.send(:truncate_text, text, 20)
      expect(result).to eq('This is a very lo...')
      expect(result.length).to eq(20)
    end
  end

  describe '#notifier_name' do
    it 'returns the notifier name without "Notifier" suffix' do
      slack_notifier_class = Class.new(described_class) do
        def validate_configuration!; end
      end
      stub_const('TechNews::Notifiers::SlackNotifier', slack_notifier_class)

      slack_notifier = TechNews::Notifiers::SlackNotifier.new(config: config, logger: logger)
      expect(slack_notifier.send(:notifier_name)).to eq('Slack')
    end
  end

  describe '#retry_with_backoff' do
    it 'succeeds on first try' do
      result = notifier.send(:retry_with_backoff) { 'success' }
      expect(result).to eq('success')
    end

    it 'retries on Faraday::Error' do
      call_count = 0
      allow(logger).to receive(:warn)

      result = notifier.send(:retry_with_backoff, max_retries: 3) do
        call_count += 1
        raise Faraday::Error, 'Network error' if call_count < 2

        'success'
      end

      expect(result).to eq('success')
      expect(call_count).to eq(2)
      expect(logger).to have_received(:warn).once
    end

    it 'raises WebhookError after max retries' do
      allow(logger).to receive(:warn)

      expect do
        notifier.send(:retry_with_backoff, max_retries: 2) do
          raise Faraday::Error, 'Network error'
        end
      end.to raise_error(TechNews::WebhookError, /Failed after 2 retries/)
    end
  end

  describe '#handle_response' do
    it 'handles successful response (200)' do
      response = instance_double(Faraday::Response, status: 200)
      allow(logger).to receive(:debug)

      expect { notifier.send(:handle_response, response) }.not_to raise_error
      expect(logger).to have_received(:debug)
    end

    it 'handles successful response (201)' do
      response = instance_double(Faraday::Response, status: 201)
      allow(logger).to receive(:debug)

      expect { notifier.send(:handle_response, response) }.not_to raise_error
    end

    it 'raises RateLimitError on 429' do
      response = instance_double(Faraday::Response, status: 429)

      expect do
        notifier.send(:handle_response, response)
      end.to raise_error(TechNews::RateLimitError, /rate limit exceeded/)
    end

    it 'raises WebhookError on 400-499' do
      response = instance_double(Faraday::Response, status: 400, body: 'Bad request')

      expect do
        notifier.send(:handle_response, response)
      end.to raise_error(TechNews::WebhookError, /client error/)
    end

    it 'raises WebhookError on 500-599' do
      response = instance_double(Faraday::Response, status: 500)

      expect do
        notifier.send(:handle_response, response)
      end.to raise_error(TechNews::WebhookError, /server error/)
    end
  end
end
