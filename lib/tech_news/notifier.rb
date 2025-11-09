# frozen_string_literal: true

require 'faraday'
require 'json'

module TechNews
  class Notifier
    attr_reader :webhook_url, :config, :logger

    MAX_RETRIES = 3
    RETRY_WAIT = 2 # seconds

    def initialize(webhook_url:, config:, logger:)
      @webhook_url = webhook_url
      @config = config
      @logger = logger
      validate_webhook_url!
    end

    def notify(summary)
      logger.info("Posting to Slack: #{summary[:article].title}")

      message = format_message(summary)
      send_to_slack(message)
    rescue StandardError => e
      logger.error("Failed to post to Slack: #{e.message}")
      raise NotifierError, "Slack notification failed: #{e.message}"
    end

    def notify_batch(summaries, wait_interval: nil)
      interval = wait_interval || config.slack_post_interval
      logger.info("Starting batch notification of #{summaries.length} summaries")

      posted_count = 0
      failed_count = 0

      summaries.each_with_index do |summary, index|
        begin
          notify(summary)
          posted_count += 1
          logger.debug("Progress: #{index + 1}/#{summaries.length} posted")

          # Wait between posts to avoid rate limiting
          sleep(interval) if index < summaries.length - 1
        rescue NotifierError => e
          # Log error but continue with other posts
          logger.error("Batch notification failed for post #{index + 1}: #{e.message}")
          failed_count += 1
        end
      end

      logger.info("Batch notification complete: #{posted_count} succeeded, #{failed_count} failed")
      { posted: posted_count, failed: failed_count }
    end

    private

    def validate_webhook_url!
      uri = URI.parse(webhook_url)
      unless uri.is_a?(URI::HTTPS) && uri.host.include?('slack.com')
        raise ConfigurationError, "Invalid Slack webhook URL"
      end
    rescue URI::InvalidURIError => e
      raise ConfigurationError, "Invalid webhook URL: #{e.message}"
    end

    def format_message(summary)
      article = summary[:article]
      summary_text = summary[:summary]

      {
        blocks: [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: truncate_text(article.title, 150),
              emoji: true
            }
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: summary_text
            }
          },
          {
            type: 'context',
            elements: [
              {
                type: 'mrkdwn',
                text: "*ソース:* #{article.source}"
              }
            ]
          },
          {
            type: 'actions',
            elements: [
              {
                type: 'button',
                text: {
                  type: 'plain_text',
                  text: '記事を読む',
                  emoji: true
                },
                url: article.url,
                action_id: 'read_article'
              }
            ]
          }
        ]
      }
    end

    def send_to_slack(message)
      retries = 0

      begin
        response = http_client.post do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = message.to_json
        end

        handle_response(response)
      rescue Faraday::Error => e
        retries += 1
        if retries < MAX_RETRIES
          wait_time = RETRY_WAIT * (2 ** (retries - 1)) # Exponential backoff
          logger.warn("Slack request failed, retrying in #{wait_time}s (attempt #{retries}/#{MAX_RETRIES})")
          sleep(wait_time)
          retry
        else
          raise WebhookError, "Failed after #{MAX_RETRIES} retries: #{e.message}"
        end
      end
    end

    def http_client
      @http_client ||= Faraday.new(url: webhook_url) do |f|
        f.options.timeout = 10
        f.options.open_timeout = 5
        f.adapter Faraday.default_adapter
      end
    end

    def handle_response(response)
      case response.status
      when 200
        logger.debug('Slack post successful')
      when 429
        raise RateLimitError, 'Slack rate limit exceeded'
      when 400..499
        raise WebhookError, "Client error: #{response.status} - #{response.body}"
      when 500..599
        raise WebhookError, "Server error: #{response.status}"
      else
        raise WebhookError, "Unexpected response: #{response.status}"
      end
    end

    def truncate_text(text, max_length)
      return text if text.length <= max_length

      text[0...(max_length - 3)] + '...'
    end
  end
end
