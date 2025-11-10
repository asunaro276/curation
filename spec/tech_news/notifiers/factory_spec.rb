# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/tech_news/notifiers/factory'
require_relative '../../../lib/tech_news/config'
require_relative '../../../lib/tech_news/logger'

RSpec.describe TechNews::Notifiers::Factory do
  let(:logger) { instance_double(TechNews::AppLogger) }
  let(:config) do
    instance_double(
      TechNews::Config,
      slack_webhook_url: 'https://hooks.slack.com/services/T00/B00/XX',
      line_channel_access_token: 'test_token',
      line_target_id: 'U123456',
      slack_post_interval: 1
    )
  end

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
  end

  describe '.create_all' do
    context 'when only Slack is enabled' do
      before do
        allow(config).to receive(:enabled_notifiers).and_return(['slack'])
      end

      it 'creates only Slack notifier' do
        notifiers = described_class.create_all(config, logger)

        expect(notifiers.length).to eq(1)
        expect(notifiers.first).to be_a(TechNews::Notifiers::SlackNotifier)
      end

      it 'logs the initialized notifiers' do
        described_class.create_all(config, logger)

        expect(logger).to have_received(:info).with(/Initialized notifiers: SlackNotifier/)
      end
    end

    context 'when only LINE is enabled' do
      before do
        allow(config).to receive(:enabled_notifiers).and_return(['line'])
      end

      it 'creates only LINE notifier' do
        notifiers = described_class.create_all(config, logger)

        expect(notifiers.length).to eq(1)
        expect(notifiers.first).to be_a(TechNews::Notifiers::LineNotifier)
      end
    end

    context 'when both Slack and LINE are enabled' do
      before do
        allow(config).to receive(:enabled_notifiers).and_return(['slack', 'line'])
      end

      it 'creates both notifiers' do
        notifiers = described_class.create_all(config, logger)

        expect(notifiers.length).to eq(2)
        expect(notifiers.map(&:class)).to contain_exactly(
          TechNews::Notifiers::SlackNotifier,
          TechNews::Notifiers::LineNotifier
        )
      end
    end

    context 'when an unknown notifier type is specified' do
      before do
        allow(config).to receive(:enabled_notifiers).and_return(['slack', 'unknown', 'line'])
      end

      it 'creates only valid notifiers' do
        notifiers = described_class.create_all(config, logger)

        expect(notifiers.length).to eq(2)
        expect(notifiers.map(&:class)).to contain_exactly(
          TechNews::Notifiers::SlackNotifier,
          TechNews::Notifiers::LineNotifier
        )
      end

      it 'logs a warning about unknown type' do
        described_class.create_all(config, logger)

        expect(logger).to have_received(:warn).with(/Unknown notifier type: unknown/)
      end
    end

    context 'when a notifier fails to initialize' do
      before do
        allow(config).to receive(:enabled_notifiers).and_return(['slack', 'line'])
        allow(config).to receive(:slack_webhook_url).and_return('invalid_url')
      end

      it 'continues with other notifiers' do
        notifiers = described_class.create_all(config, logger)

        # Should have LINE notifier only, as Slack fails
        expect(notifiers.length).to eq(1)
        expect(notifiers.first).to be_a(TechNews::Notifiers::LineNotifier)
      end

      it 'logs a warning about the failure' do
        described_class.create_all(config, logger)

        expect(logger).to have_received(:warn).with(/Failed to initialize slack notifier/)
      end
    end

    context 'when no notifiers are enabled' do
      before do
        allow(config).to receive(:enabled_notifiers).and_return([])
      end

      it 'returns an empty array' do
        notifiers = described_class.create_all(config, logger)

        expect(notifiers).to be_empty
      end

      it 'logs a warning' do
        described_class.create_all(config, logger)

        expect(logger).to have_received(:warn).with(/No notifiers were successfully initialized/)
      end
    end
  end

  describe '.create' do
    it 'creates Slack notifier for "slack" type' do
      notifier = described_class.create('slack', config, logger)

      expect(notifier).to be_a(TechNews::Notifiers::SlackNotifier)
    end

    it 'creates LINE notifier for "line" type' do
      notifier = described_class.create('line', config, logger)

      expect(notifier).to be_a(TechNews::Notifiers::LineNotifier)
    end

    it 'handles case-insensitive type names' do
      notifier = described_class.create('SLACK', config, logger)

      expect(notifier).to be_a(TechNews::Notifiers::SlackNotifier)
    end

    it 'returns nil for unknown type' do
      notifier = described_class.create('unknown', config, logger)

      expect(notifier).to be_nil
    end

    it 'logs warning for unknown type' do
      described_class.create('unknown', config, logger)

      expect(logger).to have_received(:warn).with(/Unknown notifier type: unknown/)
    end
  end
end
