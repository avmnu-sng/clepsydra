# frozen_string_literal: true

module Clepsydra
  class Subscriber
    class NoSuchEventError < StandardError; end

    attr_reader :id, :event_name

    def initialize(event_name, monotonic, listener)
      @id = if monotonic
              "monotonic_subscriber_#{Clepsydra::TokenProvider.generate}"
            else
              "subscriber_#{Clepsydra::TokenProvider.generate}"
            end
      @event_name = event_name
      @monotonic = monotonic
      @listener = listener
      @start_times = {}
    end

    def start(event_id)
      @start_times[event_id] = current_time
    end

    def finish(event_id, instrumenter_id, payload)
      started = @start_times.delete(event_id)

      raise NoSuchEventError, "#{event_id} for #{@event_name} does not exist or already completed" if started.nil?

      @listener.call(@event_name, event_id, instrumenter_id, @id, started, current_time, payload)
    end

    private

    def current_time
      if @monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      else
        Time.now
      end
    end
  end
end
