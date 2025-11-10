# frozen_string_literal: true

require_relative 'config'
require_relative 'logger'
require_relative 'errors'
require_relative 'models/article'
require_relative 'collectors/factory'
require_relative 'summarizer'
require_relative 'notifier'
require_relative 'notifiers/factory'

module TechNews
  class Orchestrator
    attr_reader :config, :logger, :collectors, :summarizer, :notifiers, :dry_run

    def initialize(config_path: 'config/sources.yml', dry_run: false)
      @dry_run = dry_run
      @logger = AppLogger.new
      @config = Config.new(config_path: config_path)
      @collectors = Collectors::Factory.create_all_from_config(config, logger)
      @summarizer = Summarizer.new(
        api_key: config.anthropic_api_key,
        config: config,
        logger: logger
      )
      @notifiers = Notifiers::Factory.create_all(config, logger)

      logger.info("Orchestrator initialized with #{collectors.length} collectors")
      logger.info("Dry run mode: #{dry_run}") if dry_run
    end

    def run
      start_time = Time.now
      logger.info("=== Starting Tech News Curation ===")

      begin
        articles = collect_articles
        return report_results(articles, [], {}, start_time) if articles.empty?

        summaries = summarize_articles(articles)
        return report_results(articles, summaries, {}, start_time) if summaries.empty?

        post_result = publish_summaries(summaries)

        report_results(articles, summaries, post_result, start_time)
      rescue StandardError => e
        handle_error(e)
        raise
      end
    end

    private

    def collect_articles
      logger.info("--- Phase 1: Collecting Articles ---")
      all_articles = []

      collectors.each do |collector|
        begin
          articles = collector.collect
          all_articles.concat(articles)
          logger.info("#{collector.name}: Collected #{articles.length} articles")
        rescue CollectorError => e
          logger.error("#{collector.name}: Collection failed - #{e.message}")
          # Continue with other collectors
        end
      end

      logger.info("Total articles collected: #{all_articles.length}")
      all_articles
    end

    def summarize_articles(articles)
      logger.info("--- Phase 2: Summarizing Articles ---")

      if dry_run
        logger.info("Dry run: Skipping summarization")
        return articles.map { |article| { article: article, summary: "[DRY RUN] Summary placeholder", model: "dry-run", timestamp: Time.now } }
      end

      summaries = summarizer.summarize_batch(articles)
      logger.info("Successfully summarized #{summaries.length}/#{articles.length} articles")
      summaries
    end

    def publish_summaries(summaries)
      logger.info("--- Phase 3: Publishing Summaries ---")

      if dry_run
        logger.info("Dry run: Skipping notification posting")
        return { notifiers: {}, total_posted: summaries.length, total_failed: 0 }
      end

      if notifiers.empty?
        logger.error("No notifiers available for publishing")
        raise NotifierError, "No notifiers configured"
      end

      results = {}
      total_posted = 0
      total_failed = 0

      notifiers.each do |notifier|
        notifier_name = notifier.class.name.split('::').last.gsub('Notifier', '')

        begin
          logger.info("Publishing to #{notifier_name}...")
          result = notifier.notify_batch(summaries)
          results[notifier_name.downcase.to_sym] = result
          total_posted += result[:posted]
          total_failed += result[:failed]
          logger.info("#{notifier_name}: Posted #{result[:posted]} (#{result[:failed]} failed)")
        rescue StandardError => e
          logger.error("#{notifier_name}: Publishing failed - #{e.message}")
          results[notifier_name.downcase.to_sym] = { posted: 0, failed: summaries.length, error: e.message }
          total_failed += summaries.length
        end
      end

      # Raise error only if all notifiers failed
      if total_posted == 0 && total_failed > 0
        raise NotifierError, "All notifiers failed to publish summaries"
      end

      results.merge(total_posted: total_posted, total_failed: total_failed, notifiers: results)
    end

    def report_results(articles, summaries, post_result, start_time)
      duration = Time.now - start_time
      logger.info("=== Curation Complete ===")
      logger.info("Duration: #{duration.round(2)}s")
      logger.info("Articles collected: #{articles.length}")
      logger.info("Articles summarized: #{summaries.length}")

      # Report per-notifier results
      if post_result[:notifiers]
        post_result[:notifiers].each do |notifier_name, result|
          next if result.is_a?(Hash) && result.empty?
          logger.info("#{notifier_name.to_s.capitalize}: #{result[:posted] || 0} posted, #{result[:failed] || 0} failed")
        end
      end

      logger.info("Total posts sent: #{post_result[:total_posted] || post_result[:posted] || 0}")
      logger.info("Total posts failed: #{post_result[:total_failed] || post_result[:failed] || 0}")

      {
        duration: duration,
        articles_collected: articles.length,
        articles_summarized: summaries.length,
        posts_sent: post_result[:total_posted] || post_result[:posted] || 0,
        posts_failed: post_result[:total_failed] || post_result[:failed] || 0,
        notifier_results: post_result[:notifiers] || {}
      }
    end

    def handle_error(error)
      logger.error("=== Fatal Error ===")
      logger.error("#{error.class}: #{error.message}")
      logger.error(error.backtrace.first(5).join("\n")) if error.backtrace
    end
  end
end
