[![Maintainability](https://api.codeclimate.com/v1/badges/906b5c8d15a66897d350/maintainability)](https://codeclimate.com/github/avmnu-sng/clepsydra/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/906b5c8d15a66897d350/test_coverage)](https://codeclimate.com/github/avmnu-sng/clepsydra/test_coverage)

# Clepsydra

**Clepsydra** is an instrumentation tool allowing instrumenting events. You can
subscribe to events to receive instrument notifications once done.

## Installation

Add this line to your `Gemfile` and `bundle install`:

```ruby
gem 'clepsydra', '~> 0.1.0'
```

Clepsydra requires **Ruby >= 2.5.0**.

## Benchmark

Run `./benchmark/report.rb` in the project root directory to benchmark
**`Clepsydra`** and **`ActiveSupport::Notifications`**. Make sure to have **Ruby >= 2.7.0**.

### Sample Report

```
================================================================================
Scenario: 1 thread with 100k instruments per thread
                                     user     system      total        real
Clepsydra                        1.661837   0.029577   1.691414 (  1.692077)
ActiveSupport::Notifications     1.296754   0.004308   1.301062 (  1.302075)

================================================================================
Scenario: 10 threads with 10k instruments per thread
                                     user     system      total        real
Clepsydra                        4.781395   3.896587   8.677982 (  6.436222)
ActiveSupport::Notifications     7.648087  12.432460  20.080547 ( 17.625330)
```

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
Clepsydra.subscribe('foo') do |event_name, event_id, instrumenter_id, subscriber_id, start, finish, payload|
  # This is a blocking call avoid long-running tasks
  #
  # event_name      [String] name of the event
  # event_id        [String] unique ID of the event
  # instrumenter_id [String] unique ID of the instrumenter who fired the event
  # subscriber_id   [String] unique ID of the current subscriber
  # start           [Time] instrumented block execution start time
  # finish          [Time] instumented block execution end time
  # payload         [Hash] the payload
end
```

In case of an error in the instrumented block, the payload additionally has:

- **`exception`**: The exception object
- **`execption_message`**: The result of calling `execption.inspect`

Note that, the time is a wall-clock time. You can use **`monotonic_subscribe`** for
better accuracy as it uses monotonic time.

### Unsubscribe

- **`Clepsydra.unsubscribe_all(event_name)`**
- **`Clepsydra.unsubscribe(subscriber)`**

You can unsubscribe either all the subscribers to a particular event or a specific subscriber.

```ruby
Clepsydra.subscribe('foo') {}
Clepsydra.subscribe('foo') {}
Clepsydra.monotonic_subscribe('foo') {}

# Unsubscribe all
Clepsydra.unsubscribe_all('foo')

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
