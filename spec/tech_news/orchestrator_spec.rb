# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe TechNews::Orchestrator do
  let(:config_file) do
    file = Tempfile.new(['sources', '.yml'])
    file.write(YAML.dump({
      'sources' => [
        { 'type' => 'rss', 'name' => 'Test RSS', 'url' => 'https://example.com/rss', 'enabled' => true }
      ],
      'limits' => { 'max_articles_per_source' => 5 },
      'slack' => { 'post_interval' => 0.1 }
    }))
    file.rewind
    file
  end

  let(:sample_rss) do
    <<~RSS
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Test Article</title>
            <link>https://example.com/article</link>
            <description>Test description</description>
          </item>
        </channel>
      </rss>
    RSS
  end

  before do
    ENV['ANTHROPIC_API_KEY'] = 'test_api_key'
    ENV['SLACK_WEBHOOK_URL'] = 'https://hooks.slack.com/services/T00/B00/XX'
  end

  after do
    config_file.close
    config_file.unlink
  end

  describe '#initialize' do
    it 'initializes with configuration' do
      orchestrator = described_class.new(config_path: config_file.path, dry_run: true)

      expect(orchestrator.config).to be_a(TechNews::Config)
      expect(orchestrator.collectors).not_to be_empty
      expect(orchestrator.summarizer).to be_a(TechNews::Summarizer)
      expect(orchestrator.notifiers).to be_an(Array)
      expect(orchestrator.notifiers.first).to be_a(TechNews::Notifiers::Base)
    end
  end

  describe '#run' do
    it 'runs full workflow in dry run mode' do
      stub_request(:get, 'https://example.com/rss')
        .to_return(status: 200, body: sample_rss)

      orchestrator = described_class.new(config_path: config_file.path, dry_run: true)
      result = orchestrator.run

      expect(result[:articles_collected]).to eq(1)
      expect(result[:articles_summarized]).to eq(1)
      expect(result[:posts_sent]).to eq(1)
    end

    it 'handles empty article collection' do
      stub_request(:get, 'https://example.com/rss')
        .to_return(status: 200, body: '<?xml version="1.0"?><rss><channel></channel></rss>')

      orchestrator = described_class.new(config_path: config_file.path, dry_run: true)
      result = orchestrator.run

      expect(result[:articles_collected]).to eq(0)
    end

    it 'continues on collector errors' do
      stub_request(:get, 'https://example.com/rss')
        .to_return(status: 500)

      orchestrator = described_class.new(config_path: config_file.path, dry_run: true)

      # Should not raise error, just log it
      expect { orchestrator.run }.not_to raise_error
    end
  end

  describe 'error handling' do
    it 'handles and logs errors gracefully' do
      orchestrator = described_class.new(config_path: config_file.path, dry_run: true)

      # Simulate an error by stubbing collect_articles to raise
      allow(orchestrator).to receive(:collect_articles).and_raise(StandardError, 'Test error')

      expect {
        orchestrator.run
      }.to raise_error(StandardError, 'Test error')
    end
  end
end
