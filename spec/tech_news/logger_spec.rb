# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe TechNews::AppLogger do
  let(:output) { StringIO.new }
  let(:logger) { described_class.new(level: 'DEBUG', output: output) }

  describe '#info' do
    it 'logs info messages' do
      logger.info('Test message')
      expect(output.string).to include('INFO')
      expect(output.string).to include('Test message')
    end
  end

  describe '#error' do
    it 'logs error messages' do
      logger.error('Error occurred')
      expect(output.string).to include('ERROR')
      expect(output.string).to include('Error occurred')
    end
  end

  describe 'sensitive data masking' do
    it 'masks Anthropic API keys' do
      logger.info('API Key: sk-ant-1234567890abcdef')
      expect(output.string).to include('[REDACTED]')
      expect(output.string).not_to include('sk-ant-1234567890abcdef')
    end

    it 'masks Slack webhook URLs' do
      logger.info('Webhook: https://hooks.slack.com/services/T00/B00/XX')
      expect(output.string).to include('[REDACTED]')
      expect(output.string).not_to include('T00/B00/XX')
    end

    it 'masks environment variables' do
      logger.info('ANTHROPIC_API_KEY=secret_key_here')
      expect(output.string).to include('[REDACTED]')
      expect(output.string).not_to include('secret_key_here')
    end
  end

  describe 'log levels' do
    it 'respects log level settings' do
      info_logger = described_class.new(level: 'INFO', output: output)
      info_logger.debug('Debug message')
      expect(output.string).not_to include('Debug message')

      info_logger.info('Info message')
      expect(output.string).to include('Info message')
    end
  end
end
