# frozen_string_literal: true

require_relative 'slack_notifier'
require_relative 'line_notifier'

module TechNews
  module Notifiers
    class Factory
      class << self
        # Creates all enabled notifiers based on configuration
        # @param config [TechNews::Config] The configuration object
        # @param logger [TechNews::AppLogger] The logger instance
        # @return [Array<TechNews::Notifiers::Base>] Array of notifier instances
        def create_all(config, logger)
          notifiers = []
          enabled_types = config.enabled_notifiers

          enabled_types.each do |type|
            begin
              notifier = create(type, config, logger)
              notifiers << notifier if notifier
            rescue StandardError => e
              logger.warn("Failed to initialize #{type} notifier: #{e.message}")
            end
          end

          if notifiers.empty?
            logger.warn("No notifiers were successfully initialized")
          else
            logger.info("Initialized notifiers: #{notifiers.map { |n| n.class.name.split('::').last }.join(', ')}")
          end

          notifiers
        end

        # Creates a single notifier based on type
        # @param type [String] The notifier type ('slack' or 'line')
        # @param config [TechNews::Config] The configuration object
        # @param logger [TechNews::AppLogger] The logger instance
        # @return [TechNews::Notifiers::Base, nil] A notifier instance or nil
        def create(type, config, logger)
          case type.to_s.downcase
          when 'slack'
            create_slack_notifier(config, logger)
          when 'line'
            create_line_notifier(config, logger)
          else
            logger.warn("Unknown notifier type: #{type}")
            nil
          end
        end

        private

        def create_slack_notifier(config, logger)
          SlackNotifier.new(
            webhook_url: config.slack_webhook_url,
            config: config,
            logger: logger
          )
        end

        def create_line_notifier(config, logger)
          LineNotifier.new(
            channel_access_token: config.line_channel_access_token,
            target_id: config.line_target_id,
            config: config,
            logger: logger
          )
        end
      end
    end
  end
end
