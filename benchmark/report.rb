#!/usr/bin/env ruby
# frozen_string_literal: true

return unless RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7.0')

require 'active_support'
require 'benchmark'

require_relative '../lib/clepsydra'

UNDER_TEST = [Clepsydra, ActiveSupport::Notifications].freeze

EVENTS_COUNT = 100_000
INSTRUMENTS_COUNT = 100_000

def subscribers(clazz)
  var = if clazz == ActiveSupport::Notifications
          :@string_subscribers
        else
          :@subscribers
        end

  clazz.send(:notifier).instance_variable_get(var).values.sum(&:count)
end

def setup
  UNDER_TEST.each do |clazz|
    EVENTS_COUNT.times { |i| clazz.subscribe("foo-#{i}") {} }
    EVENTS_COUNT.times { |i| clazz.monotonic_subscribe("foo-#{i}") {} }

    raise 'Could not subscribe to all events' if subscribers(clazz) != 2 * EVENTS_COUNT
  end
end

def teardown
  UNDER_TEST.each do |clazz|
    action = if clazz == ActiveSupport::Notifications
               :unsubscribe
             else
               :unsubscribe_all
             end

    EVENTS_COUNT.times { |i| clazz.send(action, "foo-#{i}") }
  end
end

def instrument(clazz, threads_count, batch_size)
  batch_size.times do |i|
    threads = []

    threads_count.times do |j|
      threads << Thread.new { clazz.instrument("foo-#{(batch_size * j) + i}") { nil } }
    end

    threads.each(&:join)
  end
end

begin
  puts 'Benchmarking 100k instruments with 2 subscribers for each event'
  puts 'Each scenario is run 3 times and the total time is reported'

  setup

  threads_counts = [1, 10, 25, 50, 100, 200, 400]
  batch_size_strs = %w[100k 10k 4k 2k 1k 500 250]

  threads_counts.zip(batch_size_strs).each do |threads_count, batch_size_str|
    batch_size = INSTRUMENTS_COUNT / threads_count

    if threads_count * batch_size != INSTRUMENTS_COUNT
      warn "Invalid threads count #{threads_count}. Skipping benchmarking!"

      next
    end

    puts
    puts '=' * 80
    puts <<-SCENARIO.strip.gsub(/\s+/, ' ')
      Scenario: #{threads_count} thread#{threads_count > 1 ? 's' : ''}
      with #{batch_size_str} instruments per thread
    SCENARIO

    Benchmark.bm(30) do |bm|
      UNDER_TEST.each do |clazz|
        bm.report(clazz.name) do
          3.times do
            if threads_count == 1
              INSTRUMENTS_COUNT.times { |i| clazz.instrument("foo-#{i}") { nil } }
            else
              instrument(clazz, threads_count, batch_size)
            end
          end
        end
      end
    end
  end
ensure
  teardown
end
