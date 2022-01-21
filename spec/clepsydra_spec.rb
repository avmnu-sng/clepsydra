# frozen_string_literal: true

require 'concurrent/set'
require 'set'
require 'stringio'

RSpec.describe Clepsydra do
  def string_hash_to_hash(hash_string)
    Hash[*hash_string.gsub(/[^'"\w\d]/, ' ').strip.split.map { |str| str.gsub(/['"]/, '') }]
  end

  def capture_stdout
    old = $stdout
    $stdout = fake = StringIO.new

    yield

    fake.string
  ensure
    $stdout = old
  end

  subject(:clepsydra) { described_class }

  let(:instrumenter) { clepsydra.send(:instrumenter) }
  let(:notifier) { clepsydra.send(:notifier) }

  before do
    notifier.instance_variable_get(:@subscribers).each_key do |event_name|
      clepsydra.unsubscribe(event_name)
    end
  end

  describe '.notifier' do
    it 'has one notifier across threads' do
      notifiers = Concurrent::Set.new
      threads = []

      10.times { threads << Thread.new { 100.times { notifiers << clepsydra.send(:notifier) } } }
      threads.each(&:join)

      expect(notifiers).to eq(Set[clepsydra.send(:notifier)])
      expect(notifiers.first).to be_a(clepsydra::Notifier)
    end
  end

  describe '.instrumenter' do
    it 'has one instrumenter per thread' do
      instrumenters = Concurrent::Set.new
      threads = []

      10.times { threads << Thread.new { instrumenters << clepsydra.send(:instrumenter) } }
      threads.each(&:join)

      expect(instrumenters.count).to eq(10)
      expect(instrumenters).to all(be_a(clepsydra::Instrumenter))
      expect(instrumenters.map(&:id).count).to eq(10)
      expect(instrumenters.map(&:id)).to all(match(/instrumenter_[0-9a-z]{10}/))
    end
  end

  describe '.subscribe' do
    it 'raises error for a subscription without a block' do
      expect { clepsydra.subscribe('foo') }.to raise_error(clepsydra::InvalidSubscriptionError)
    end

    it 'returns a subscriber on subscription' do
      subscriber = clepsydra.subscribe('foo') {}

      expect(subscriber).to be_a(clepsydra::Subscriber)
      expect(subscriber.id).to match(/subscriber_[0-9a-z]{10}/)
      expect(subscriber.event_name).to eq('foo')
      expect(subscriber.instance_variable_get(:@monotonic)).to eq(false)
      expect(subscriber.instance_variable_get(:@listener)).to be_a(Proc)
    end

    it 'creates a new subscriber on each subscription' do
      subscribers = Set.new
      100.times { subscribers << clepsydra.subscribe('foo') {} }

      expect(subscribers.count).to eq(100)
      expect(subscribers).to all(be_a(clepsydra::Subscriber))
      expect(subscribers.map(&:id).count).to eq(100)
      expect(subscribers.map(&:id)).to all(match(/subscriber_[0-9a-z]{10}/))
      expect(subscribers.map(&:event_name).uniq).to eq(['foo'])
      expect(subscribers.map { |s| s.instance_variable_get(:@monotonic) }.uniq).to eq([false])
      expect(subscribers.map { |s| s.instance_variable_get(:@listener) }).to all(be_a(Proc))
    end

    it 'returns wall-clock time' do
      current_time = Time.now
      subscriber = clepsydra.subscribe('foo') {}

      expect(subscriber.send(:current_time, wall_clock: current_time)).to eq(current_time)
    end
  end

  describe '.monotonic_subscribe' do
    it 'raises error for a subscription without a block' do
      expect { clepsydra.monotonic_subscribe('foo-monotonic') }
        .to raise_error(clepsydra::InvalidSubscriptionError)
    end

    it 'returns a subscriber on subscription' do
      subscriber = clepsydra.monotonic_subscribe('foo-monotonic') {}

      expect(subscriber).to be_a(clepsydra::Subscriber)
      expect(subscriber.id).to match(/subscriber_[0-9a-z]{10}/)
      expect(subscriber.event_name).to eq('foo-monotonic')
      expect(subscriber.instance_variable_get(:@monotonic)).to eq(true)
      expect(subscriber.instance_variable_get(:@listener)).to be_a(Proc)
    end

    it 'creates a new subscriber on each subscription' do
      subscribers = Set.new
      100.times { subscribers << clepsydra.monotonic_subscribe('foo-monotonic') {} }

      expect(subscribers.count).to eq(100)
      expect(subscribers).to all(be_a(clepsydra::Subscriber))
      expect(subscribers.map(&:id).count).to eq(100)
      expect(subscribers.map(&:id)).to all(match(/subscriber_[0-9a-z]{10}/))
      expect(subscribers.map(&:event_name).uniq).to eq(['foo-monotonic'])
      expect(subscribers.map { |s| s.instance_variable_get(:@monotonic) }.uniq).to eq([true])
      expect(subscribers.map { |s| s.instance_variable_get(:@listener) }).to all(be_a(Proc))
    end

    it 'returns monotonic time' do
      current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      subscriber = clepsydra.monotonic_subscribe('foo') {}

      expect(subscriber.send(:current_time, monotonic: current_time)).to eq(current_time)
    end
  end

  describe '.unsubscribe' do
    context 'when event' do
      before do
        5.times { clepsydra.subscribe('foo') {} }
        5.times { clepsydra.monotonic_subscribe('foo') {} }
      end

      context 'when subscribed' do
        before { allow(notifier).to receive(:unsubscribe).with('foo').and_call_original }

        it 'unsubscribes all the subscribers' do
          expect(notifier.subscribed?('foo')).to eq(true)

          clepsydra.unsubscribe('foo')

          expect(notifier.subscribed?('foo')).to eq(false)
          expect(notifier).to have_received(:unsubscribe).with('foo')
        end
      end

      context 'when not subscribed' do
        before { allow(notifier).to receive(:unsubscribe).with('foo-unsubscribed').and_call_original }

        it 'does nothing' do
          expect(notifier.subscribed?('foo-unsubscribed')).to eq(false)

          clepsydra.unsubscribe('foo-unsubscribed')

          expect(notifier.subscribed?('foo-unsubscribed')).to eq(false)
          expect(notifier).to have_received(:unsubscribe).with('foo-unsubscribed')
        end
      end
    end

    context 'when subscriber' do
      let(:subscribers) { notifier.instance_variable_get(:@subscribers)['foo'] }

      it 'unsubscribes given subscriber' do
        first = clepsydra.subscribe('foo') {}
        second = clepsydra.subscribe('foo') {}
        third = clepsydra.monotonic_subscribe('foo') {}

        expect(subscribers).to contain_exactly(first, second, third)

        clepsydra.unsubscribe(second)

        expect(subscribers).to contain_exactly(first, third)

        clepsydra.unsubscribe(first)

        expect(subscribers).to contain_exactly(third)
      end
    end
  end

  describe '.instrument' do
    before { allow(instrumenter).to receive(:instrument).and_call_original }

    describe 'thread safety' do
      it 'is thread safe' do
        def _instrument(threads_count)
          batch_size = 10_000 / threads_count

          raise 'Invalid threads count' if (batch_size * threads_count) != 10_000

          batch_size.times do |i|
            threads = []

            threads_count.times do |j|
              threads << Thread.new { clepsydra.instrument("foo-#{(batch_size * j) + i}") { nil } }
            end

            threads.each(&:join)
          end
        end

        10_000.times { |i| clepsydra.subscribe("foo-#{i}") {} }
        10_000.times { |i| clepsydra.monotonic_subscribe("foo-#{i}") {} }

        10_000.times do |i|
          expect(notifier.instance_variable_get(:@subscribers)["foo-#{i}"].count).to eq(2)
        end

        subscribers = notifier.instance_variable_get(:@subscribers).values.flatten

        expect(subscribers.count).to eq(20_000)

        subscribers.each { |s| allow(s).to receive(:current_time).and_call_original }

        [10, 20, 40].each do |threads_count|
          expect { _instrument(threads_count) }.not_to raise_error
        end

        expect(subscribers).to all(have_received(:current_time).exactly(6).times)
      end
    end

    describe 'instrument time' do
      before { Timecop.freeze }

      after { Timecop.return }

      it 'has same start and finish time for all the subscribers of same event' do
        100.times { clepsydra.subscribe('foo') { |*args| $stdout.puts args } }

        output = capture_stdout { clepsydra.instrument('foo') {} }.split("\n")
        start_times = output.values_at(*1.step(399, 4).to_a)
        finish_times = output.values_at(*2.step(399, 4).to_a)

        expect(start_times).to all(eq(Time.now.to_s))
        expect(finish_times).to all(eq(Time.now.to_s))
      end
    end

    context 'when subscribed' do
      context 'when no block' do
        it 'raises error' do
          expect { clepsydra.instrument('foo') }.to raise_error(clepsydra::InvalidInstrumentError)
        end
      end

      context 'when block given' do
        context 'when block raises exeception' do
          it 'raises exeception' do
            clepsydra.subscribe('foo') { nil }

            expect { clepsydra.instrument('foo') { raise 'Exception!' } }
              .to raise_error(RuntimeError, 'Exception!')
          end

          it 'notifies all the subscribers with the exeception details' do
            payload = nil
            payload_monotonic = nil
            error = nil

            begin
              clepsydra.subscribe('foo') { |*, data| payload = data }
              clepsydra.monotonic_subscribe('foo') { |*, data| payload_monotonic = data }
              clepsydra.instrument('foo') { raise 'Exception!' }
            rescue StandardError => e
              error = e
            end

            expect(payload[:exception]).to eq(error)
            expect(payload[:exception_message]).to eq(error.inspect)
            expect(payload_monotonic[:exception]).to eq(error)
            expect(payload_monotonic[:exception_message]).to eq(error.inspect)
          end
        end

        context 'when no error' do
          it 'notifies all the subscribers' do
            sum = 0
            sum_monotonic = 0

            clepsydra.subscribe('foo') { |*, payload| sum += payload[:num] }
            clepsydra.subscribe('bar') { |*, payload| sum += payload[:num] }
            clepsydra.monotonic_subscribe('foo') { |*, payload| sum_monotonic += payload[:num] }
            clepsydra.monotonic_subscribe('bar') { |*, payload| sum_monotonic += payload[:num] }

            100.times do |i|
              threads = []

              10.times do |j|
                threads << Thread.new do
                  payload = {}
                  clepsydra.instrument('foo', payload) { payload[:num] = i + j + 2 }

                  payload = {}
                  clepsydra.instrument('bar', payload) { payload[:num] = i + j + 2 }
                end
              end

              threads.each(&:join)
            end

            expect([sum, sum_monotonic]).to all(eq(112_000))
          end
        end
      end
    end

    context 'when not subscribed' do
      it 'executes the block' do
        payload = { name: 'foo', time: Time.now }

        expect(clepsydra.instrument('foo', payload) { |*args| args }).to eq([payload])
        expect(instrumenter).not_to have_received(:instrument)
      end
    end
  end

  describe '.start' do
    context 'when have subscribers' do
      it 'returns the event id' do
        clepsydra.subscribe('foo') {}

        expect(clepsydra.start('foo')).to match(/event_[0-9a-z]{10}/)
      end
    end

    context 'when no subscribers' do
      it 'does nothing' do
        expect(clepsydra.start('foo')).to eq(nil)
      end
    end
  end

  describe '.finish' do
    context 'when have subscribers' do
      before { clepsydra.subscribe('foo') { |*args| $stdout.puts args } }

      context 'with invalid event id' do
        it 'raises error' do
          expect { clepsydra.finish('foo', 'foo-id') }.to raise_error(
            clepsydra::Subscriber::NoSuchEventError,
            'foo-id for foo does not exist or already completed'
          )
        end
      end

      context 'with valid event id' do
        before { Timecop.freeze }

        after { Timecop.return }

        it 'finishes the event and notifies the subscriber' do
          start_time = Time.now
          finish_time = start_time + 3
          event_id = clepsydra.start('foo')

          Timecop.travel(finish_time)

          output = capture_stdout { clepsydra.finish('foo', event_id) }.split("\n")
          event_data = string_hash_to_hash(output[0])

          expect(output.count).to eq(4)
          expect(event_data['event_name']).to eq('foo')
          expect(event_data['event_id']).to match(/event_[0-9a-z]{10}/)
          expect(event_data['notifier_id']).to match(/notifier_[0-9a-z]{10}/)
          expect(event_data['instrumenter_id']).to match(/instrumenter_[0-9a-z]{10}/)
          expect(event_data['subscriber_id']).to match(/subscriber_[0-9a-z]{10}/)
          expect(output[1]).to eq(start_time.to_s)
          expect(output[2]).to eq(finish_time.to_s)
          expect(output[3]).to eq('{}')
        end
      end
    end

    context 'when no subscribers' do
      it 'does nothing' do
        expect(clepsydra.finish('foo', 'foo-id')).to eq(nil)
      end
    end
  end
end
