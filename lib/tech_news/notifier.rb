# frozen_string_literal: true

require_relative 'notifiers/slack_notifier'

module TechNews
  # Backward compatibility wrapper for SlackNotifier
  # This class is deprecated and maintained for backward compatibility only.
  # Use TechNews::Notifiers::SlackNotifier directly instead.
  class Notifier < Notifiers::SlackNotifier
  end
end
