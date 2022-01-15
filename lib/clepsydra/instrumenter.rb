# frozen_string_literal: true

module Clepsydra
  class Instrumenter
    attr_reader :id

    def initialize(notifier)
      @id = "instrumenter_#{Clepsydra::TokenProvider.generate}"
      @notifier = notifier
    end

    def instrument(event_name, payload = {})
      event_id = start(event_name)

      yield payload if block_given?
    rescue Exception => e
      payload[:exception] = e
      payload[:exception_message] = e.inspect

      raise e
    ensure
      finish(event_name, event_id, payload)
    end

    def start(event_name)
      @notifier.start(event_name, "event_#{Clepsydra::TokenProvider.generate}")
    end

    def finish(event_name, event_id, payload)
      @notifier.finish(event_name, event_id, @id, payload)
    end
  end
end
