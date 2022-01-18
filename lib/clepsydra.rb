# frozen_string_literal: true

require 'concurrent/map'
require 'pry'
require 'securerandom'

require_relative 'clepsydra/instrumenter'
require_relative 'clepsydra/notifier'
require_relative 'clepsydra/subscriber'
require_relative 'clepsydra/token_provider'
require_relative 'clepsydra/version'

module Clepsydra
  class InvalidSubscriptionError < StandardError; end

  class << self
    def subscribe(event_name, &block)
      raise InvalidSubscriptionError, 'No block given' unless block

      notifier.subscribe(event_name, false, &block)
    end

    def monotonic_subscribe(event_name, &block)
      raise InvalidSubscriptionError, 'No block given' unless block

      notifier.subscribe(event_name, true, &block)
    end

    def unsubscribe_all(event_name)
      notifier.unsubscribe_all(event_name) if event_name.is_a?(String)
    end

    def unsubscribe(subscriber)
      notifier.unsubscribe(subscriber) if subscriber.is_a?(Clepsydra::Subscriber)
    end

    def instrument(event_name, payload = {})
      if notifier.subscribed?(event_name)
        instrumenter.instrument(event_name, payload) { yield payload if block_given? }
      elsif block_given?
        yield payload
      end
    end

    def start(event_name)
      instrumenter.start(event_name) if notifier.subscribed?(event_name)
    end

    def finish(event_name, event_id, payload = {})
      instrumenter.finish(event_name, event_id, payload) if notifier.subscribed?(event_name)
    end

    private

    def instrumenter
      Thread.current[notifier.id] ||= Clepsydra::Instrumenter.new(notifier)
    end

    def notifier
      return @notifier if defined?(@notifier)

      @notifier = Clepsydra::Notifier.new
    end
  end
end
