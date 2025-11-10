# frozen_string_literal: true

module TechNews
  # Base error class for all TechNews errors
  class Error < StandardError; end

  # Collector errors
  class CollectorError < Error; end
  class NetworkError < CollectorError; end
  class ParseError < CollectorError; end

  # Summarizer errors
  class SummarizerError < Error; end
  class APIError < SummarizerError; end
  class TokenLimitError < SummarizerError; end

  # Notifier errors
  class NotifierError < Error; end
  class WebhookError < NotifierError; end
  class RateLimitError < NotifierError; end

  # Configuration errors
  class ConfigurationError < Error; end
end
