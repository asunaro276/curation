# frozen_string_literal: true

require_relative 'rss_collector'
require_relative 'github_trending_collector'

module TechNews
  module Collectors
    class Factory
      def self.create_from_config(source_config, config, logger)
        type = source_config['type']
        source_config['name']

        case type
        when 'rss'
          create_rss_collector(source_config, config, logger)
        when 'github_trending'
          create_github_trending_collector(source_config, config, logger)
        else
          raise ConfigurationError, "Unsupported collector type: #{type}"
        end
      end

      def self.create_all_from_config(config, logger)
        config.enabled_sources.map do |source_config|
          create_from_config(source_config, config, logger)
        rescue ConfigurationError => e
          logger.error("Failed to create collector: #{e.message}")
          nil
        end.compact
      end

      def self.create_rss_collector(source_config, config, logger)
        url = source_config['url']
        raise ConfigurationError, "RSS collector requires 'url' field" unless url

        RssCollector.new(
          name: source_config['name'],
          url: url,
          config: config,
          logger: logger
        )
      end

      def self.create_github_trending_collector(source_config, config, logger)
        GithubTrendingCollector.new(
          name: source_config['name'],
          language: source_config['language'],
          config: config,
          logger: logger
        )
      end
    end
  end
end
