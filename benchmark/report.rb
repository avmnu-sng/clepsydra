#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support'
require 'benchmark/ips'

require_relative '../lib/clepsydra'

UNDER_TEST = [Clepsydra, ActiveSupport::Notifications].freeze

SUBSCRIBERS_COUNT = 1_000_000
INSTRUMENTS_COUNT = 1_000_000

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
    SUBSCRIBERS_COUNT.times { |i| clazz.subscribe("foo-#{i}") {} }

    raise 'Could not subscribe to all events' if subscribers(clazz) != SUBSCRIBERS_COUNT
  end
end

def teardown
  UNDER_TEST.each do |clazz|
    SUBSCRIBERS_COUNT.times { |i| clazz.unsubscribe("foo-#{i}") }
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
  puts 'Benchmarking 1M unique instruments'

  setup

  threads_counts = [1, 10, 25, 50, 100, 200, 400]
  batch_size_strs = %w[1M 100K 40K 20K 10K 5K 2.5K]

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

    Benchmark.ips do |bm|
      bm.config(stats: :bootstrap, confidence: 99.9)

      UNDER_TEST.each do |clazz|
        bm.report(clazz.name) do
          if threads_count == 1
            INSTRUMENTS_COUNT.times { |i| clazz.instrument("foo-#{i}") { nil } }
          else
            instrument(clazz, threads_count, batch_size)
          end
        end
      end

      bm.compare!
    end
  end
ensure
  teardown
end
