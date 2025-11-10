# frozen_string_literal: true

require_relative 'base'

module TechNews
  module Notifiers
    class SlackNotifier < Base
      attr_reader :webhook_url

      def initialize(webhook_url:, config:, logger:)
        @webhook_url = webhook_url
        super(config: config, logger: logger)
      end

      def notify(summary)
        logger.info("Posting to Slack: #{summary[:article].title}")

        message = format_message(summary)
        send_to_slack(message)
      rescue RateLimitError, WebhookError
        # Re-raise these specific errors as-is
        raise
      rescue StandardError => e
        logger.error("Failed to post to Slack: #{e.message}")
        raise NotifierError, "Slack notification failed: #{e.message}"
      end

      protected

      def validate_configuration!
        uri = URI.parse(webhook_url)
        unless uri.is_a?(URI::HTTPS) && uri.host.include?('slack.com')
          raise ConfigurationError, "Invalid Slack webhook URL"
        end
      rescue URI::InvalidURIError => e
        raise ConfigurationError, "Invalid webhook URL: #{e.message}"
      end

      def default_wait_interval
        config.slack_post_interval
      end

      private

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
        retry_with_backoff do
          response = http_client.post do |req|
            req.headers['Content-Type'] = 'application/json'
            req.body = message.to_json
          end

          handle_response(response)
        end
      end

      def http_client
        @http_client ||= Faraday.new(url: webhook_url) do |f|
          f.options.timeout = 10
          f.options.open_timeout = 5
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
