[![Maintainability](https://api.codeclimate.com/v1/badges/906b5c8d15a66897d350/maintainability)](https://codeclimate.com/github/avmnu-sng/clepsydra/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/906b5c8d15a66897d350/test_coverage)](https://codeclimate.com/github/avmnu-sng/clepsydra/test_coverage)
[![Gem Version](https://badge.fury.io/rb/clepsydra.svg)](https://badge.fury.io/rb/clepsydra)

# Clepsydra

**Clepsydra** is an instrumentation tool allowing instrumenting events. You can
subscribe to events to receive instrument notifications once done.

## Why Clepsydra

- Clepsydra provides correct execution time information for multiple subscribers
of the same event compared to `ActiveSupport::Notifications`:

  ```ruby
  5.times do
    ActiveSupport::Notifications.subscribe('foo') do |_name, start, finish, _id, _payload|
      puts "#{start.to_i} #{finish.to_i} #{finish - start}"

      sleep 1
    end
  end

  ActiveSupport::Notifications.instrument('foo') {}

  # 1642778642 1642778642 8.0e-06
  # 1642778642 1642778643 1.003928
  # 1642778642 1642778644 2.008781
  # 1642778642 1642778645 3.014062
  # 1642778642 1642778646 4.016004

  5.times do
    Clepsydra.subscribe('foo') do |_event_data, start, finish, _payload|
      puts "#{start.to_i} #{finish.to_i} #{finish - start}"

      sleep 1
    end
  end

  Clepsydra.instrument('foo') {}

  # 1642778782 1642778782 1.7e-05
  # 1642778782 1642778782 1.7e-05
  # 1642778782 1642778782 1.7e-05
  # 1642778782 1642778782 1.7e-05
  # 1642778782 1642778782 1.7e-05
  ```

- Clepsydra offers APIs to measure non-blocking events correctly.

## Installation

Add this line to your `Gemfile` and `bundle install`:

```ruby
gem 'clepsydra', '~> 0.1.0'
```

Clepsydra requires **Ruby >= 2.5.0**.

## Benchmark

Read the [benchmark](./BENCHMARK.md) document.

## Usage

### Instrument

- **`Clepsyndra.instrument(event_name[, payload])`**

Instrumenters provide a way to instrument an event. These first execute the block
and notify all the subscribers even if the instrumented block raises an exception.
In such a case, the notification contains the exception information in the payload.

```ruby
Clepsydra.instrument('foo', { bar: 'baz' }) do
  FirstTask.perform
  SecondTask.perform
end
```


### Subscribe

- **`Clepsyndra.subscribe(event_name) { |*args| } => Clepsyndra::Subscriber`**
- **`Clepsyndra.monotonic_subscribe(event_name) { |*args| } => Clepsyndra::Subscriber`**

Subscribers consume instrumented events. You can register multiple subscribers
for the same event.

```ruby
Clepsydra.subscribe('foo') do |event_data, start, finish, payload|
  # This is a blocking call avoid long-running tasks
  #
  # event_data            [Hash] the event data
  #   * :event_name       [String] the event name
  #   * :event_id         [String] unique ID of the event
  #   * :notifier_id      [String] unique ID of the notifier
  #   * :instrumenter_id  [String] unique ID of the instrumenter who fired the event
  #   * :subscriber_id    [String] unique ID of the current subscriber
  # start                 [Time] instrumented block execution start time
  # finish                [Time] instumented block execution end time
  # payload               [Hash] the payload
end
```

In case of an error in the instrumented block, the payload additionally has:

- **`exception`**: The exception object
- **`execption_message`**: The result of calling `execption.inspect`

Note that, the time is a wall-clock time. You can use **`monotonic_subscribe`** for
better accuracy as it uses monotonic time.

### Unsubscribe

- **`Clepsydra.unsubscribe(event_name_or_subscriber)`**

You can unsubscribe either all the subscribers to a particular event or a specific subscriber.

```ruby
Clepsydra.subscribe('foo') {}
Clepsydra.subscribe('foo') {}
Clepsydra.monotonic_subscribe('foo') {}

# Unsubscribe all
Clepsydra.unsubscribe('foo')

first = Clepsydra.subscribe('foo') {}
second = Clepsydra.monotonic_subscribe('foo') {}

# Unsubscribe one
Clepsydra.unsubscribe(second)
```

### Explicit Instrument

- **`Clepsydra.start(event_name) => String`**
- **`Clepsydra.finish(event_name, event_id[, payload])`**

You can explicitly mark the start of an event and then fire the finish that notifies
all the subscribers. You must fire both **`start`** and **`finish`** in the same
thread context. It allows to instrument multiple events running in a block explicitly
when it is not desired to instrument the entire block or each event entirely.

```ruby
tasks.each do |task|
  Clepsydra.instrument('foo') do
    task.on_complete { |data| }
    task.submit # Non-blocking
  end
end
```

The above does not provide accurate instrumentation as it exits immediately after
submitting the tasks.

```ruby
tasks.each do |task|
  event_id = Clepsydra.start('foo')
  task.on_complete { |data| Clepsydra.finish('foo', event_id, data) }
  task.submit # Non-blocking
end
```

## Contributing

Read the [contribution guide](https://github.com/avmnu-sng/clepsydra/blob/main/.github/CONTRIBUTING.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Clepsydra's codebases, issue trackers, chat rooms and
mailing lists is expected to follow the [Code of Conduct](https://github.com/avmnu-sng/clepsydra/blob/main/.github/CODE_OF_CONDUCT.md).
