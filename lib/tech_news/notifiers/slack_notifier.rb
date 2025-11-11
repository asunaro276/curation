# frozen_string_literal: true

require_relative 'base'

module TechNews
  module Notifiers
    class SlackNotifier < Base
      attr_reader :webhook_url

      # Slackのメッセージサイズ制限（約40,000文字、安全マージンを持たせて35,000）
      MAX_MESSAGE_SIZE = 35_000

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

      # 統合メッセージで通知（複数記事を1つのメッセージに）
      def notify_consolidated(summaries)
        logger.info("Posting consolidated message to Slack with #{summaries.length} articles")

        message = format_consolidated_message(summaries)
        send_to_slack(message)
      rescue RateLimitError, WebhookError
        # Re-raise these specific errors as-is
        raise
      rescue StandardError => e
        logger.error("Failed to post consolidated message to Slack: #{e.message}")
        raise NotifierError, "Slack consolidated notification failed: #{e.message}"
      end

      protected

      def validate_configuration!
        uri = URI.parse(webhook_url)
        unless uri.is_a?(URI::HTTPS) && uri.host.include?('slack.com')
          raise ConfigurationError, 'Invalid Slack webhook URL'
        end
      rescue URI::InvalidURIError => e
        raise ConfigurationError, "Invalid webhook URL: #{e.message}"
      end

      def default_wait_interval
        config.slack_post_interval
      end

      # 統合メッセージのフォーマット（複数記事を1つのメッセージに）
      def format_consolidated_message(summaries)
        # 空の要約をフィルタリング
        valid_summaries = summaries.select { |s| s[:summary] && !s[:summary].strip.empty? }

        blocks = []

        # ヘッダー: 記事件数を表示
        blocks << {
          type: 'header',
          text: {
            type: 'plain_text',
            text: "本日の技術ニュース (#{valid_summaries.length}件)",
            emoji: true
          }
        }

        # 各記事のセクション
        valid_summaries.each_with_index do |summary, index|
          article = summary[:article]
          summary_text = summary[:summary]

          # 記事タイトルセクション
          blocks << {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: "*#{index + 1}. #{article.title}*"
            }
          }

          # 要約テキスト
          blocks << {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: summary_text
            }
          }

          # ソース情報とリンクボタン
          blocks << {
            type: 'section',
            fields: [
              {
                type: 'mrkdwn',
                text: "*ソース:* #{article.source}"
              }
            ],
            accessory: {
              type: 'button',
              text: {
                type: 'plain_text',
                text: '記事を読む',
                emoji: true
              },
              url: article.url,
              action_id: "read_article_#{index}"
            }
          }

          # 記事間の区切り線（最後の記事以外）
          blocks << { type: 'divider' } if index < valid_summaries.length - 1
        end

        message = { blocks: blocks }
        validate_message_size(message)
        message
      end

      # メッセージサイズを検証
      def validate_message_size(message)
        message_json = message.to_json
        size = message_json.bytesize

        if size > MAX_MESSAGE_SIZE
          logger.warn("Message size #{size} bytes exceeds limit of #{MAX_MESSAGE_SIZE} bytes")
          raise WebhookError, "メッセージサイズが制限(#{MAX_MESSAGE_SIZE}バイト)を超えています: #{size}バイト"
        end

        logger.debug("Message size: #{size} bytes (within #{MAX_MESSAGE_SIZE} byte limit)")
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
