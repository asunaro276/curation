# frozen_string_literal: true

require 'faraday'
require 'json'

module TechNews
  module Notifiers
    class Base
      attr_reader :config, :logger

      MAX_RETRIES = 3
      RETRY_WAIT = 2 # seconds

      def initialize(config:, logger:)
        @config = config
        @logger = logger
        validate_configuration!
      end

      # Abstract method to be implemented by subclasses
      def notify(summary)
        raise NotImplementedError, "#{self.class} must implement #notify"
      end

      # Batch notification with rate limiting
      # consolidated: true の場合、複数記事を1つのメッセージに統合して送信
      def notify_batch(summaries, wait_interval: nil, consolidated: true)
        interval = wait_interval || default_wait_interval
        logger.info("Starting batch notification of #{summaries.length} summaries to #{notifier_name} (consolidated: #{consolidated})")

        # 統合メッセージモードで、サブクラスがサポートしている場合
        if consolidated && respond_to?(:notify_consolidated, true)
          begin
            notify_consolidated(summaries)
            logger.info("#{notifier_name}: Consolidated batch notification complete: 1 message sent with #{summaries.length} articles")
            { posted: summaries.length, failed: 0 }
          rescue RateLimitError, WebhookError
            # 重要なエラーは再raise
            raise
          rescue StandardError => e
            logger.error("#{notifier_name}: Consolidated batch notification failed: #{e.message}")
            { posted: 0, failed: summaries.length }
          end
        else
          # 従来の個別投稿モード
          posted_count = 0
          failed_count = 0

          summaries.each_with_index do |summary, index|
            begin
              notify(summary)
              posted_count += 1
              logger.debug("#{notifier_name}: Progress #{index + 1}/#{summaries.length} posted")

              # Wait between posts to avoid rate limiting
              sleep(interval) if index < summaries.length - 1
            rescue StandardError => e
              # Log error but continue with other posts
              logger.error("#{notifier_name}: Batch notification failed for post #{index + 1}: #{e.message}")
              failed_count += 1
            end
          end

          logger.info("#{notifier_name}: Batch notification complete: #{posted_count} succeeded, #{failed_count} failed")
          { posted: posted_count, failed: failed_count }
        end
      end

      protected

      # Abstract method to be implemented by subclasses
      def validate_configuration!
        raise NotImplementedError, "#{self.class} must implement #validate_configuration!"
      end

      # Abstract method to be implemented by subclasses
      def notifier_name
        class_name = self.class.name || 'Unknown'
        class_name.split('::').last.gsub('Notifier', '')
      end

      # Default wait interval between posts (can be overridden by subclasses)
      def default_wait_interval
        2
      end

      # Truncate text to a maximum length
      def truncate_text(text, max_length)
        return text if text.length <= max_length

        text[0...(max_length - 3)] + '...'
      end

      # Retry logic with exponential backoff
      def retry_with_backoff(max_retries: MAX_RETRIES)
        retries = 0

        begin
          yield
        rescue Faraday::Error => e
          retries += 1
          if retries < max_retries
            wait_time = RETRY_WAIT * (2 ** (retries - 1)) # Exponential backoff
            logger.warn("#{notifier_name}: Request failed, retrying in #{wait_time}s (attempt #{retries}/#{max_retries})")
            sleep(wait_time)
            retry
          else
            raise WebhookError, "#{notifier_name}: Failed after #{max_retries} retries: #{e.message}"
          end
        end
      end

      # Handle HTTP response codes
      def handle_response(response, service_name: notifier_name)
        case response.status
        when 200, 201
          logger.debug("#{service_name} post successful")
        when 429
          raise RateLimitError, "#{service_name} rate limit exceeded"
        when 400..499
          raise WebhookError, "#{service_name} client error: #{response.status} - #{response.body}"
        when 500..599
          raise WebhookError, "#{service_name} server error: #{response.status}"
        else
          raise WebhookError, "#{service_name} unexpected response: #{response.status}"
        end
      end
    end
  end
end
