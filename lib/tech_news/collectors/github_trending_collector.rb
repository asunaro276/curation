# frozen_string_literal: true

require 'json'
require 'nokogiri'
require_relative 'base'

module TechNews
  module Collectors
    class GithubTrendingCollector < Base
      TRENDING_URL = 'https://github.com/trending'

      attr_reader :language

      def initialize(name:, config:, logger:, language: nil)
        super(name: name, config: config, logger: logger)
        @language = language
      end

      def fetch
        url = build_url
        fetch_url(url)
      end

      def parse(html_data)
        doc = Nokogiri::HTML(html_data)
        articles = extract_repositories(doc)
        limit_articles(articles)
      rescue StandardError => e
        raise ParseError, "Failed to parse GitHub Trending: #{e.message}"
      end

      private

      def build_url
        if language && !language.empty?
          "#{TRENDING_URL}/#{language}"
        else
          TRENDING_URL
        end
      end

      def extract_repositories(doc)
        # GitHub Trending uses article tags for each repository
        repos = doc.css('article.Box-row')

        repos.map do |repo|
          extract_article_from_repo(repo)
        rescue ArgumentError => e
          logger.warn("#{name}: Skipping invalid repository - #{e.message}")
          nil
        end.compact
      end

      def extract_article_from_repo(repo)
        # Extract repository name and URL
        h2 = repo.at_css('h2 a')
        return nil unless h2

        repo_path = h2['href']
        repo_url = "https://github.com#{repo_path}"
        repo_name = h2.text.strip.gsub(/\s+/, ' ')

        # Extract description
        description_elem = repo.at_css('p.col-9')
        description = description_elem ? description_elem.text.strip : nil

        # Extract stars today
        stars_elem = repo.at_css('span.d-inline-block.float-sm-right')
        stars_today = stars_elem ? stars_elem.text.strip : '0'

        # Extract language
        lang_elem = repo.at_css('span[itemprop="programmingLanguage"]')
        language_text = lang_elem ? lang_elem.text.strip : 'Unknown'

        # Extract total stars
        total_stars_elem = repo.at_css('svg.octicon-star')&.parent
        total_stars = total_stars_elem ? total_stars_elem.text.strip : '0'

        Models::Article.new(
          title: "#{repo_name} - GitHub Trending",
          url: repo_url,
          published_at: Time.now, # GitHub Trending doesn't provide publish date
          description: description,
          source: name,
          metadata: {
            language: language_text,
            stars_today: stars_today,
            total_stars: total_stars,
            repository: repo_name
          }
        )
      end
    end
  end
end
