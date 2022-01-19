# frozen_string_literal: true

module Clepsydra
  class Subscriber
    class NoSuchEventError < StandardError; end

    attr_reader :id, :event_name

    def initialize(event_name, monotonic, listener)
      @id = "subscriber_#{Clepsydra::TokenProvider.generate}"
      @event_name = event_name
      @monotonic = monotonic
      @listener = listener
      @start_times = {}
    end

    def start(event_id, current_times)
      @start_times[event_id] = current_time(current_times)
    end

    def finish(event_id, notifier_id, instrumenter_id, current_times, payload)
      start_time = @start_times.delete(event_id)

      raise NoSuchEventError, "#{event_id} for #{@event_name} does not exist or already completed" if start_time.nil?

      finish_time = current_time(current_times)
      event_data = event_data(event_id, notifier_id, instrumenter_id)

      @listener.call(event_data, start_time, finish_time, payload)
    end

    private

    def event_data(event_id, notifier_id, instrumenter_id)
      {
        'event_name' => @event_name,
        'event_id' => event_id,
        'notifier_id' => notifier_id,
        'instrumenter_id' => instrumenter_id,
        'subscriber_id' => @id
      }
    end

    def current_time(current_times)
      if @monotonic
        current_times[:monotonic]
      else
        current_times[:wall_clock]
      end
    end
  end
end
