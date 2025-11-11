# frozen_string_literal: true

require 'uri'
require 'time'

module TechNews
  module Models
    class Article
      attr_reader :title, :url, :published_at, :description, :source, :metadata

      def initialize(title:, url:, source:, published_at: nil, description: nil, metadata: {})
        @title = title
        @url = url
        @source = source
        @published_at = parse_time(published_at)
        @description = description
        @metadata = metadata || {}
        validate!
      end

      def valid?
        !title.nil? && !title.empty? &&
          !url.nil? && valid_url?(url) &&
          !source.nil? && !source.empty?
      end

      def to_h
        {
          title: title,
          url: url,
          published_at: published_at&.iso8601,
          description: description,
          source: source,
          metadata: metadata
        }
      end

      def inspect
        "#<Article title=#{title.inspect} url=#{url.inspect} source=#{source.inspect}>"
      end

      private

      def validate!
        errors = []
        errors << 'title is required' if title.nil? || title.empty?
        errors << 'url is required' if url.nil? || url.empty?
        errors << 'url is invalid' if url && !valid_url?(url)
        errors << 'source is required' if source.nil? || source.empty?

        raise ArgumentError, "Article validation failed: #{errors.join(', ')}" unless errors.empty?
      end

      def valid_url?(url_string)
        uri = URI.parse(url_string)
        uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        false
      end

      def parse_time(time_value)
        return nil if time_value.nil?
        return time_value if time_value.is_a?(Time)

        Time.parse(time_value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
