# frozen_string_literal: true

require 'anthropic'

module TechNews
  class Summarizer
    attr_reader :api_key, :model, :config, :logger

    def initialize(api_key:, config:, logger:, model: nil)
      @api_key = api_key
      @model = model || config.claude_model
      @config = config
      @logger = logger
      @client = Anthropic::Client.new(access_token: api_key)
    end

    def summarize(article)
      logger.info("Summarizing: #{article.title}")

      content = build_content(article)
      prompt = build_prompt(article, content)

      begin
        response = call_api(prompt)
        parse_response(response, article)
      rescue StandardError => e
        logger.error("Failed to summarize #{article.title}: #{e.message}")
        raise SummarizerError, "Summarization failed: #{e.message}"
      end
    end

    def summarize_batch(articles, wait_interval: 1)
      logger.info("Starting batch summarization of #{articles.length} articles")

      summaries = []
      failed_count = 0

      articles.each_with_index do |article, index|
        begin
          summary = summarize(article)
          summaries << summary
          logger.debug("Progress: #{index + 1}/#{articles.length} articles summarized")

          # Wait between API calls to avoid rate limiting
          sleep(wait_interval) if index < articles.length - 1
        rescue SummarizerError => e
          # Log error but continue with other articles
          logger.error("Batch summarization failed for article #{index + 1}: #{e.message}")
          failed_count += 1
        end
      end

      logger.info("Batch summarization complete: #{summaries.length} succeeded, #{failed_count} failed")
      summaries
    end

    private

    def build_content(article)
      content = article.description || article.title
      truncate_content(content, max_tokens: config.max_content_tokens)
    end

    def build_prompt(article, content)
      <<~PROMPT
        あなたは技術ニュースのキュレーターです。
        以下の記事を日本語で要約してください。

        タイトル: #{article.title}
        URL: #{article.url}
        ソース: #{article.source}
        内容: #{content}

        以下の形式で出力してください:
        1. 2-3文の簡潔な要約
        2. 重要なポイント（箇条書き、最大3点）

        要約:
      PROMPT
    end

    def call_api(prompt)
      response = @client.messages(
        parameters: {
          model: model,
          max_tokens: 1000,
          messages: [
            { role: 'user', content: prompt }
          ]
        }
      )

      unless response['content'] && response['content'][0]
        raise APIError, "Invalid API response format"
      end

      response
    rescue Faraday::Error => e
      # Log detailed error information
      if e.response
        logger.error("API Error Response: #{e.response[:status]} - #{e.response[:body]}")
      end
      handle_api_error(e)
    end

    def parse_response(response, article)
      summary_text = response['content'][0]['text']

      {
        article: article,
        summary: summary_text,
        model: model,
        timestamp: Time.now
      }
    end

    def truncate_content(text, max_tokens:)
      # Rough approximation: 1 token ≈ 4 characters for Japanese
      # Use a conservative estimate
      max_chars = max_tokens * 3

      if text.length > max_chars
        logger.debug("Truncating content from #{text.length} to #{max_chars} chars")
        text[0...max_chars] + "..."
      else
        text
      end
    end

    def handle_api_error(error)
      case error
      when Faraday::TooManyRequestsError
        raise RateLimitError, "API rate limit exceeded"
      when Faraday::TimeoutError
        raise APIError, "API request timed out"
      else
        raise APIError, "API error: #{error.message}"
      end
    end
  end
end
