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
        title = item.title
        return '' unless title
        title.respond_to?(:content) ? title.content : title.to_s
      end

      def extract_url(item)
        link = item.link
        return '' unless link
        link.respond_to?(:href) ? link.href : link.to_s
      end

      def extract_published_at(item)
        # Try different date fields depending on RSS version
        # RSS 2.0: pubDate
        # Dublin Core: dc_date
        # Atom: published, updated
        return item.pubDate if item.respond_to?(:pubDate) && item.pubDate
        return item.dc_date if item.respond_to?(:dc_date) && item.dc_date
        return item.published if item.respond_to?(:published) && item.published
        return item.updated if item.respond_to?(:updated) && item.updated
        nil
      end

      def extract_description(item)
        # Try multiple fields for description
        content = nil

        # Try description field
        if item.respond_to?(:description) && item.description
          desc = item.description
          content = desc.respond_to?(:content) ? desc.content : desc.to_s
        end

        # Try content_encoded if description is empty
        if (content.nil? || content.empty?) && item.respond_to?(:content_encoded) && item.content_encoded
          content = item.content_encoded.to_s
        end

        # Try summary if still empty
        if (content.nil? || content.empty?) && item.respond_to?(:summary) && item.summary
          sum = item.summary
          content = sum.respond_to?(:content) ? sum.content : sum.to_s
        end

        return nil unless content

        # Strip HTML tags if present
        strip_html(content.to_s)
      end

      def extract_metadata(item)
        metadata = {}

        if item.respond_to?(:author) && item.author
          author = item.author
          if author.respond_to?(:name)
            name = author.name
            metadata[:author] = name.respond_to?(:content) ? name.content : name.to_s
          else
            metadata[:author] = author.to_s
          end
        end

        if item.respond_to?(:categories) && item.categories
          metadata[:categories] = item.categories.map do |cat|
            cat.respond_to?(:content) ? cat.content : cat.to_s
          end
        end

        metadata
      end

      def strip_html(text)
        # Simple HTML tag removal
        text.gsub(/<[^>]*>/, '').strip
      end
    end
  end
end
