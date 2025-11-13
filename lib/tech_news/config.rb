# frozen_string_literal: true

require 'yaml'

module TechNews
  class Config
    class ConfigurationError < StandardError; end

    # デフォルト値の定数定義
    DEFAULT_SYSTEM_PROMPT = 'あなたは技術ニュースのキュレーターです。以下の記事を日本語で要約してください。'
    DEFAULT_OUTPUT_FORMAT = <<~FORMAT
      以下の形式で出力してください:
      - 2-3文の簡潔な要約
      - 重要なポイント（箇条書き、最大3点）
    FORMAT

    # プロンプトの最大長制限（Claude APIの制限を考慮）
    MAX_PROMPT_LENGTH = 2000

    attr_reader :sources, :limits, :slack, :anthropic_api_key, :slack_webhook_url,
                :log_level, :claude_model, :line_channel_access_token, :line_target_id,
                :enabled_notifiers, :system_prompt, :output_format

    def initialize(config_path: 'config/sources.yml')
      @config_path = config_path
      load_config
      load_env_vars
      validate!
    end

    def enabled_sources
      @sources.select { |s| s['enabled'] }
    end

    def max_articles_per_source
      @limits['max_articles_per_source'] || 5
    end

    def max_content_tokens
      @limits['max_content_tokens'] || 4000
    end

    def api_timeout
      @limits['api_timeout'] || 30
    end

    def http_timeout
      @limits['http_timeout'] || 10
    end

    def slack_post_interval
      @slack['post_interval'] || 1
    end

    def slack_max_posts_per_batch
      @slack['max_posts_per_batch'] || 10
    end

    private

    def load_config
      raise ConfigurationError, "Configuration file not found: #{@config_path}" unless File.exist?(@config_path)

      config = YAML.load_file(@config_path)
      @sources = config['sources'] || []
      @limits = config['limits'] || {}
      @slack = config['slack'] || {}

      # Load summarization settings
      summarization = config['summarization'] || {}
      @system_prompt = summarization['system_prompt'] || DEFAULT_SYSTEM_PROMPT
      @output_format = summarization['output_format'] || DEFAULT_OUTPUT_FORMAT
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "Invalid YAML in configuration file: #{e.message}"
    end

    def load_env_vars
      @anthropic_api_key = ENV['ANTHROPIC_API_KEY']
      @slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
      @log_level = ENV['LOG_LEVEL'] || 'INFO'
      @claude_model = ENV['CLAUDE_MODEL'] || 'claude-3-5-sonnet-20241022'

      # LINE settings
      @line_channel_access_token = ENV['LINE_CHANNEL_ACCESS_TOKEN']
      @line_target_id = ENV['LINE_USER_ID'] || ENV['LINE_GROUP_ID']

      # Enabled notifiers (default: slack only for backward compatibility)
      notifiers_env = ENV['ENABLED_NOTIFIERS'] || 'slack'
      @enabled_notifiers = notifiers_env.split(',').map(&:strip).reject(&:empty?)
    end

    def validate!
      errors = []

      if @anthropic_api_key.nil? || @anthropic_api_key.empty?
        errors << 'ANTHROPIC_API_KEY environment variable is required'
      end
      errors << 'No sources defined in configuration' if @sources.empty?
      errors << 'No enabled sources found' if enabled_sources.empty?

      # Validate enabled notifiers
      if @enabled_notifiers.empty?
        errors << 'At least one notifier must be enabled (ENABLED_NOTIFIERS environment variable)'
      end

      # Validate notifier-specific requirements
      if @enabled_notifiers.include?('slack') && (@slack_webhook_url.nil? || @slack_webhook_url.empty?)
        errors << 'SLACK_WEBHOOK_URL environment variable is required when Slack notifier is enabled'
      end

      if @enabled_notifiers.include?('line')
        if @line_channel_access_token.nil? || @line_channel_access_token.empty?
          errors << 'LINE_CHANNEL_ACCESS_TOKEN environment variable is required when LINE notifier is enabled'
        end
        if @line_target_id.nil? || @line_target_id.empty?
          errors << 'LINE_USER_ID or LINE_GROUP_ID environment variable is required when LINE notifier is enabled'
        end
      end

      # Validate source structure
      @sources.each_with_index do |source, index|
        errors << "Source #{index}: missing 'type' field" unless source['type']
        errors << "Source #{index}: missing 'name' field" unless source['name']
        errors << "Source #{index}: 'enabled' must be a boolean" unless [true, false].include?(source['enabled'])
      end

      # Validate summarization prompts
      errors.concat(validate_prompt('system_prompt', @system_prompt))
      errors.concat(validate_prompt('output_format', @output_format))

      raise ConfigurationError, "Configuration validation failed:\n  - #{errors.join("\n  - ")}" unless errors.empty?
    end

    def validate_prompt(field_name, value)
      errors = []

      # 文字列であることを確認
      unless value.is_a?(String)
        errors << "#{field_name} must be a string"
        return errors
      end

      # 空文字列でないことを確認（空白のみもNG）
      errors << "#{field_name} cannot be empty or contain only whitespace" if value.strip.empty?

      # 最大長チェック
      if value.length > MAX_PROMPT_LENGTH
        errors << "#{field_name} exceeds maximum length of #{MAX_PROMPT_LENGTH} characters (current: #{value.length})"
      end

      errors
    end
  end
end
