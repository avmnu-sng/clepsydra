# frozen_string_literal: true

require 'mutex_m'

module Clepsydra
  class Notifier
    include Mutex_m

    attr_reader :id

    def initialize
      @id = "notifier_#{Clepsydra::TokenProvider.generate}"
      @subscribers = Hash.new { |h, k| h[k] = [] }

      super
    end

    def subscribe(event_name, monotonic, &block)
      subscriber = Clepsydra::Subscriber.new(event_name, monotonic, block)

      synchronize { @subscribers[event_name] << subscriber }

      subscriber
    end

    def unsubscribe_all(event_name)
      synchronize { @subscribers.delete(event_name) }
    end

    def unsubscribe(subscriber)
      synchronize { @subscribers[subscriber.event_name].delete(subscriber) }
    end

    def start(event_name, event_id)
      synchronize { @subscribers[event_name].each { |s| s.start(event_id) } }

      event_id
    end

    def finish(event_name, event_id, instrumenter_id, payload)
      synchronize { @subscribers[event_name].each { |s| s.finish(event_id, instrumenter_id, payload) } }
    end

    def subscribed?(event_name)
      synchronize { @subscribers[event_name] }.any?
    end
  end
end
