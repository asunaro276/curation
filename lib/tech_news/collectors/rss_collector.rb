# frozen_string_literal: true

require 'rss'
require_relative 'base'

module TechNews
  module Collectors
    class RssCollector < Base
      attr_reader :url

      def initialize(name:, url:, config:, logger:)
        super(name: name, config: config, logger: logger)
        @url = url
        validate_url!
      end

      def fetch
        fetch_url(url)
      end

      def parse(rss_data)
        feed = RSS::Parser.parse(rss_data, false)

        unless feed
          raise ParseError, "Failed to parse RSS feed"
        end

        articles = extract_articles(feed)
        limit_articles(articles)
      rescue RSS::Error => e
        raise ParseError, "RSS parsing error: #{e.message}"
      end

      private

      def validate_url!
        uri = URI.parse(url)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          raise ConfigurationError, "Invalid RSS URL: #{url}"
        end
      rescue URI::InvalidURIError => e
        raise ConfigurationError, "Invalid RSS URL: #{e.message}"
      end

      def extract_articles(feed)
        items = feed.items || []

        items.map do |item|
          begin
            Models::Article.new(
              title: extract_title(item),
              url: extract_url(item),
              published_at: extract_published_at(item),
              description: extract_description(item),
              source: name,
              metadata: extract_metadata(item)
            )
          rescue ArgumentError => e
            logger.warn("#{name}: Skipping invalid article - #{e.message}")
            nil
          end
        end.compact
      end

      def extract_title(item)
        item.title&.content || item.title.to_s
      end

      def extract_url(item)
        item.link&.href || item.link.to_s
      end

      def extract_published_at(item)
        item.pubDate || item.dc_date || item.published || nil
      end

      def extract_description(item)
        # Try multiple fields for description
        content = item.description&.content || item.description ||
                 item.content_encoded || item.summary&.content || item.summary

        return nil unless content

        # Strip HTML tags if present
        strip_html(content.to_s)
      end

      def extract_metadata(item)
        metadata = {}
        metadata[:author] = item.author&.name&.content || item.author.to_s if item.respond_to?(:author) && item.author
        metadata[:categories] = item.categories.map(&:content) if item.respond_to?(:categories) && item.categories
        metadata
      end

      def strip_html(text)
        # Simple HTML tag removal
        text.gsub(/<[^>]*>/, '').strip
      end
    end
  end
end
