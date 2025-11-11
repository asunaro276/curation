# frozen_string_literal: true

require_relative 'base'

module TechNews
  module Notifiers
    class LineNotifier < Base
      attr_reader :channel_access_token, :target_id

      LINE_API_URL = 'https://api.line.me/v2/bot/message/push'

      def initialize(channel_access_token:, target_id:, config:, logger:)
        @channel_access_token = channel_access_token
        @target_id = target_id
        super(config: config, logger: logger)
      end

      def notify(summary)
        logger.info("Posting to LINE: #{summary[:article].title}")

        message = format_message(summary)
        send_to_line(message)
      rescue RateLimitError, WebhookError
        # Re-raise these specific errors as-is
        raise
      rescue StandardError => e
        logger.error("Failed to post to LINE: #{e.message}")
        raise NotifierError, "LINE notification failed: #{e.message}"
      end

      protected

      def validate_configuration!
        if channel_access_token.nil? || channel_access_token.empty?
          raise ConfigurationError,
                'LINE Channel Access Token is required'
        end
        raise ConfigurationError, 'LINE Target ID is required' if target_id.nil? || target_id.empty?
      end

      def default_wait_interval
        2 # LINE default interval
      end

      private

      def format_message(summary)
        article = summary[:article]
        summary_text = summary[:summary]

        # Truncate text to fit LINE's limits
        title = truncate_text(article.title, 100)
        body_text = truncate_text(summary_text, 2000)

        {
          to: target_id,
          messages: [
            {
              type: 'flex',
              altText: title,
              contents: build_flex_message(article, title, body_text)
            }
          ]
        }
      end

      def build_flex_message(article, title, body_text)
        {
          type: 'bubble',
          header: {
            type: 'box',
            layout: 'vertical',
            contents: [
              {
                type: 'text',
                text: title,
                weight: 'bold',
                size: 'lg',
                wrap: true,
                color: '#1DB446'
              }
            ]
          },
          body: {
            type: 'box',
            layout: 'vertical',
            contents: [
              {
                type: 'text',
                text: body_text,
                wrap: true,
                size: 'sm',
                color: '#666666'
              },
              {
                type: 'separator',
                margin: 'md'
              },
              {
                type: 'text',
                text: "ソース: #{article.source}",
                size: 'xs',
                color: '#999999',
                margin: 'md'
              }
            ]
          },
          footer: {
            type: 'box',
            layout: 'vertical',
            contents: [
              {
                type: 'button',
                action: {
                  type: 'uri',
                  label: '記事を読む',
                  uri: article.url
                },
                style: 'primary',
                color: '#1DB446'
              }
            ]
          }
        }
      end

      def send_to_line(message)
        retry_with_backoff do
          response = http_client.post do |req|
            req.headers['Content-Type'] = 'application/json'
            req.headers['Authorization'] = "Bearer #{channel_access_token}"
            req.body = message.to_json
          end

          handle_response(response)
        end
      end

      def http_client
        @http_client ||= Faraday.new(url: LINE_API_URL) do |f|
          f.options.timeout = 30
          f.options.open_timeout = 20
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
