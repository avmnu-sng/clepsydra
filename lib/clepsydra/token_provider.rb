# frozen_string_literal: true

module Clepsydra
  module TokenProvider
    RANGE_END = 36**10
    RANGE_START = (RANGE_END / 36) - 1

    def self.generate
      rand(RANGE_START..RANGE_END).to_s(36)
    end
  end
end
