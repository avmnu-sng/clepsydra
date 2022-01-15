# frozen_string_literal: true

require 'concurrent/set'
require 'set'
require 'stringio'

RSpec.describe Clepsydra do
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
      clepsydra.unsubscribe_all(event_name)
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
      allow(Time).to receive(:now).and_call_original

      subscriber = clepsydra.subscribe('foo') {}
      subscriber.send(:current_time)

      expect(Time).to have_received(:now)
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
      expect(subscriber.id).to match(/monotonic_subscriber_[0-9a-z]{10}/)
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
      expect(subscribers.map(&:id)).to all(match(/monotonic_subscriber_[0-9a-z]{10}/))
      expect(subscribers.map(&:event_name).uniq).to eq(['foo-monotonic'])
      expect(subscribers.map { |s| s.instance_variable_get(:@monotonic) }.uniq).to eq([true])
      expect(subscribers.map { |s| s.instance_variable_get(:@listener) }).to all(be_a(Proc))
    end

    it 'returns monotonic time' do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_call_original

      subscriber = clepsydra.monotonic_subscribe('foo') {}
      subscriber.send(:current_time)

      expect(Process).to have_received(:clock_gettime).with(Process::CLOCK_MONOTONIC)
    end
  end

  describe '.unsubscribe_all' do
    before do
      5.times { clepsydra.subscribe('foo') {} }
      5.times { clepsydra.monotonic_subscribe('foo') {} }
    end

    context 'when subscribed' do
      before { allow(notifier).to receive(:unsubscribe_all).with('foo').and_call_original }

      it 'unsubscribes all the subscribers' do
        expect(notifier.subscribed?('foo')).to eq(true)

        clepsydra.unsubscribe_all('foo')

        expect(notifier.subscribed?('foo')).to eq(false)
        expect(notifier).to have_received(:unsubscribe_all).with('foo')
      end
    end

    context 'when not subscribed' do
      before { allow(notifier).to receive(:unsubscribe_all).with('foo-unsubscribed').and_call_original }

      it 'does nothing' do
        expect(notifier.subscribed?('foo-unsubscribed')).to eq(false)

        clepsydra.unsubscribe_all('foo-unsubscribed')

        expect(notifier.subscribed?('foo-unsubscribed')).to eq(false)
        expect(notifier).to have_received(:unsubscribe_all).with('foo-unsubscribed')
      end
    end
  end

  describe '.unsubscribe' do
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

  describe '.instrument' do
    before { allow(instrumenter).to receive(:instrument).and_call_original }

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

      subscribers.each { |s| allow(s).to receive(:current_time).with(no_args).and_call_original }

      allow(Time).to receive(:now).and_call_original
      allow(Process).to receive(:clock_gettime).and_call_original

      [10, 20, 40].each do |threads_count|
        expect { _instrument(threads_count) }.not_to raise_error
      end

      expect(subscribers).to all(have_received(:current_time).with(no_args).exactly(6).times)

      expect(Time).to have_received(:now).with(no_args).exactly(60_000).times
      expect(Process).to have_received(:clock_gettime).with(Process::CLOCK_MONOTONIC).exactly(60_000).times
    end

    context 'when subscribed' do
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

            mutex = Mutex.new

            clepsydra.subscribe('foo') { |*, payload| mutex.synchronize { sum += payload[:num] } }
            clepsydra.monotonic_subscribe('foo') { |*, payload| mutex.synchronize { sum_monotonic += payload[:num] } }
            clepsydra.subscribe('bar') { |*, payload| mutex.synchronize { sum += payload[:num] } }
            clepsydra.monotonic_subscribe('bar') { |*, payload| mutex.synchronize { sum_monotonic += payload[:num] } }

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

      context 'when no block' do
        before do
          2.times { clepsydra.subscribe('foo') { |*args| $stdout.puts args } }
          2.times { clepsydra.monotonic_subscribe('foo') { |*args| $stdout.puts args } }
        end

        it 'notifies all the subscribers' do
          threads = []
          outputs = []

          mutex = Mutex.new

          5.times do
            threads << Thread.new do
              outputs << mutex.synchronize { capture_stdout { clepsydra.instrument('foo') } }
            end
          end

          threads.each(&:join)

          expect(outputs.count).to eq(5)

          events_id = Set.new
          instrumenters_id = Set.new
          subscribers_id = Set.new

          outputs.each do |output|
            lines = output.split("\n")

            expect(lines.count).to eq(28)
            expect(lines.values_at(0, 7, 14, 21)).to all(eq('foo'))
            expect(lines.values_at(1, 8, 15, 22).uniq.count).to eq(1)
            expect(lines.values_at(2, 9, 16, 23).uniq.count).to eq(1)
            expect(lines.values_at(3, 10, 17, 24).uniq.count).to eq(4)

            events_id |= lines.values_at(1, 8, 15, 22)
            instrumenters_id |= lines.values_at(2, 9, 16, 23)
            subscribers_id |= lines.values_at(3, 10, 17, 24)
          end

          expect(events_id.count).to eq(5)
          expect(instrumenters_id.count).to eq(5)
          expect(subscribers_id.count).to eq(4)
        end
      end
    end

    context 'when not subscribed' do
      context 'when block given' do
        it 'executes the block' do
          payload = { name: 'foo', time: Time.now }

          expect(clepsydra.instrument('foo', payload) { |*args| args }).to eq([payload])
          expect(instrumenter).not_to have_received(:instrument)
        end
      end

      context 'when no block' do
        it 'does nothing' do
          expect(clepsydra.instrument('foo')).to eq(nil)
        end
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

          expect(output.count).to eq(7)
          expect(output[0]).to eq('foo')
          expect(output[1]).to match(/event_[0-9a-z]{10}/)
          expect(output[2]).to match(/instrumenter_[0-9a-z]{10}/)
          expect(output[3]).to match(/subscriber_[0-9a-z]{10}/)
          expect(output[4]).to eq(start_time.to_s)
          expect(output[5]).to eq(finish_time.to_s)
          expect(output[6]).to eq('{}')
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
