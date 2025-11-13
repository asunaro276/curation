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

        raise NetworkError, "HTTP #{response.status} for #{url}" unless response.success?

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

      # 前日の日付範囲を計算する
      # @return [Array<Time, Time>] 前日の開始時刻と終了時刻の配列
      def calculate_yesterday_range
        now = Time.now
        yesterday = now - 86_400 # 1日 = 86400秒
        start_time = Time.new(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0)
        end_time = Time.new(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59)
        [start_time, end_time]
      end

      # 記事を前日の日付範囲でフィルタリングする
      # @param articles [Array<Article>] フィルタリング対象の記事配列
      # @return [Array<Article>] フィルタリング後の記事配列
      def filter_by_date(articles)
        start_time, end_time = calculate_yesterday_range
        logger.debug("#{name}: Filtering articles published between #{start_time} and #{end_time}")

        filtered = articles.select { |article| article_in_date_range?(article, start_time, end_time) }

        logger.info("#{name}: Filtered from #{articles.length} to #{filtered.length} articles in date range")
        filtered
      end

      # 記事が日付範囲内にあるかチェックする
      # @param article [Article] チェック対象の記事
      # @param start_time [Time] 開始時刻
      # @param end_time [Time] 終了時刻
      # @return [Boolean] 記事が日付範囲内にある場合true
      def article_in_date_range?(article, start_time, end_time)
        if article.published_at.nil?
          logger.warn("#{name}: Article '#{article.title}' has no published_at, excluding from results")
          return false
        end

        in_range = article.published_at >= start_time && article.published_at <= end_time
        log_exclusion(article) unless in_range
        in_range
      end

      # 除外された記事をログに記録する
      # @param article [Article] 除外された記事
      def log_exclusion(article)
        logger.debug("#{name}: Excluding article '#{article.title}' published at #{article.published_at}")
      end
    end
  end
end
