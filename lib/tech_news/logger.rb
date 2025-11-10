# frozen_string_literal: true

require 'logger'

module TechNews
  class AppLogger
    SENSITIVE_PATTERNS = [
      /ANTHROPIC_API_KEY=[^\s]+/,
      /sk-ant-[^\s]+/,  # Anthropic API keys
      /xoxb-[^\s]+/,     # Slack bot tokens
      /hooks\.slack\.com\/services\/[^\s]+/  # Slack webhook URLs
    ].freeze

    attr_reader :logger

    def initialize(level: nil, output: $stdout)
      @logger = Logger.new(output)
      @logger.level = parse_level(level || ENV['LOG_LEVEL'] || 'INFO')
      @logger.formatter = method(:formatter)
    end

    def debug(message)
      @logger.debug(mask_sensitive_data(message))
    end

    def info(message)
      @logger.info(mask_sensitive_data(message))
    end

    def warn(message)
      @logger.warn(mask_sensitive_data(message))
    end

    def error(message)
      @logger.error(mask_sensitive_data(message))
    end

    def fatal(message)
      @logger.fatal(mask_sensitive_data(message))
    end

    private

    def formatter(severity, datetime, _progname, msg)
      timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
      "[#{timestamp}] #{severity.ljust(5)} - #{msg}\n"
    end

    def mask_sensitive_data(message)
      masked = message.to_s
      SENSITIVE_PATTERNS.each do |pattern|
        masked = masked.gsub(pattern, '[REDACTED]')
      end
      masked
    end

    def parse_level(level_str)
      case level_str.upcase
      when 'DEBUG' then Logger::DEBUG
      when 'INFO' then Logger::INFO
      when 'WARN' then Logger::WARN
      when 'ERROR' then Logger::ERROR
      when 'FATAL' then Logger::FATAL
      else Logger::INFO
      end
    end
  end
end
