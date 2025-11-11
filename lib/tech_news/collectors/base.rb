# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'faraday/follow_redirects'

module TechNews
  module Collectors
    class Base
      attr_reader :name, :config, :logger

      def initialize(name:, config:, logger:)
        @name = name
        @config = config
        @logger = logger
      end

      # Abstract method - must be implemented by subclasses
      def fetch
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end

      # Abstract method - must be implemented by subclasses
      def parse(data)
        raise NotImplementedError, "#{self.class} must implement #parse"
      end

      # Main entry point - fetches and parses articles
      def collect
        logger.info("#{name}: Starting collection")
        data = fetch
        articles = parse(data)
        logger.info("#{name}: Collected #{articles.length} articles")
        articles
      rescue StandardError => e
        logger.error("#{name}: Collection failed - #{e.class}: #{e.message}")
        raise CollectorError, "Failed to collect from #{name}: #{e.message}"
      end

      protected

      # HTTP client with retry logic
      def http_client
        @http_client ||= Faraday.new do |f|
          f.request :retry, {
            max: 3,
            interval: 0.5,
            interval_randomness: 0.5,
            backoff_factor: 2,
            exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
          }
          f.response :follow_redirects, limit: 5
          f.options.timeout = config.http_timeout
          f.options.open_timeout = 5
          f.headers['User-Agent'] = 'TechNewsCurator/1.0'
          f.adapter Faraday.default_adapter
        end
      end

      # Fetch URL with error handling
      def fetch_url(url)
        logger.debug("#{name}: Fetching #{url}")
        response = http_client.get(url)

        unless response.success?
          raise NetworkError, "HTTP #{response.status} for #{url}"
        end

        response.body
      rescue Faraday::Error => e
        raise NetworkError, "Network error fetching #{url}: #{e.message}"
      end

      # Limit articles based on config
      def limit_articles(articles)
        max = config.max_articles_per_source
        if articles.length > max
          logger.debug("#{name}: Limiting from #{articles.length} to #{max} articles")
          articles.first(max)
        else
          articles
        end
      end
    end
  end
end
