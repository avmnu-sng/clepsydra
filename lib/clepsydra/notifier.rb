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

    def unsubscribe(event_name_or_subscriber)
      synchronize do
        if event_name_or_subscriber.is_a?(String)
          @subscribers.delete(event_name_or_subscriber)
        else
          event_name = event_name_or_subscriber.event_name

          @subscribers[event_name].delete(event_name_or_subscriber)
          @subscribers.delete(event_name) if @subscribers[event_name].length == 1
        end
      end
    end

    def start(event_name)
      event_id = "event_#{Clepsydra::TokenProvider.generate}"
      start_times = current_times

      synchronize do
        @subscribers[event_name].each do |subscriber|
          subscriber.start(event_id, start_times)
        end
      end

      event_id
    end

    def finish(event_name, event_id, instrumenter_id, payload)
      finish_times = current_times

      synchronize do
        @subscribers[event_name].each do |subscriber|
          subscriber.finish(event_id, @id, instrumenter_id, finish_times, payload)
        end
      end
    end

    def subscribed?(event_name)
      synchronize { @subscribers[event_name] }.any?
    end

    private

    def current_times
      {
        wall_clock: Time.now,
        monotonic: Process.clock_gettime(Process::CLOCK_MONOTONIC)
      }
    end
  end
end
