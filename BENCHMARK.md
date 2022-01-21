# Benchmark

Run `./benchmark/report.rb` in the project root directory to benchmark
**`Clepsydra`** and **`ActiveSupport::Notifications`**.

## Sample Report (Ruby 2.7)

```
Benchmarking 1M unique instruments

================================================================================
Scenario: 1 thread with 1M instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.196  (± 0.0%) i/s -      1.000  in   5.113330s
ActiveSupport::Notifications
                          0.301  (± 4.5%) i/s -      2.000  in   6.650617s
                   with 99.9% confidence

Comparison:
ActiveSupport::Notifications:        0.3 i/s
           Clepsydra:        0.2 i/s - 1.54x  (± 0.07) slower
                   with 99.9% confidence


================================================================================
Scenario: 10 threads with 100K instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.046  (± 0.0%) i/s -      1.000  in  21.655149s
ActiveSupport::Notifications
                          0.014  (± 0.0%) i/s -      1.000  in  72.752881s
                   with 99.9% confidence

Comparison:
           Clepsydra:        0.0 i/s
ActiveSupport::Notifications:        0.0 i/s - 3.36x  (± 0.00) slower
                   with 99.9% confidence


================================================================================
Scenario: 25 threads with 40K instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.042  (± 0.0%) i/s -      1.000  in  24.032117s
ActiveSupport::Notifications
                          0.015  (± 0.0%) i/s -      1.000  in  65.460899s
                   with 99.9% confidence

Comparison:
           Clepsydra:        0.0 i/s
ActiveSupport::Notifications:        0.0 i/s - 2.72x  (± 0.00) slower
                   with 99.9% confidence


================================================================================
Scenario: 50 threads with 20K instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.040  (± 0.0%) i/s -      1.000  in  24.955935s
ActiveSupport::Notifications
                          0.015  (± 0.0%) i/s -      1.000  in  66.928480s
                   with 99.9% confidence

Comparison:
           Clepsydra:        0.0 i/s
ActiveSupport::Notifications:        0.0 i/s - 2.68x  (± 0.00) slower
                   with 99.9% confidence


================================================================================
Scenario: 100 threads with 10K instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.039  (± 0.0%) i/s -      1.000  in  25.563106s
ActiveSupport::Notifications
                          0.015  (± 0.0%) i/s -      1.000  in  68.724159s
                   with 99.9% confidence

Comparison:
           Clepsydra:        0.0 i/s
ActiveSupport::Notifications:        0.0 i/s - 2.69x  (± 0.00) slower
                   with 99.9% confidence


================================================================================
Scenario: 200 threads with 5K instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.036  (± 0.0%) i/s -      1.000  in  27.408376s
ActiveSupport::Notifications
                          0.013  (± 0.0%) i/s -      1.000  in  75.988921s
                   with 99.9% confidence

Comparison:
           Clepsydra:        0.0 i/s
ActiveSupport::Notifications:        0.0 i/s - 2.77x  (± 0.00) slower
                   with 99.9% confidence


================================================================================
Scenario: 400 threads with 2.5K instruments per thread
Warming up --------------------------------------
           Clepsydra     1.000  i/100ms
ActiveSupport::Notifications
                         1.000  i/100ms
Calculating -------------------------------------
           Clepsydra      0.033  (± 0.0%) i/s -      1.000  in  30.255325s
ActiveSupport::Notifications
                          0.013  (± 0.0%) i/s -      1.000  in  74.627220s
                   with 99.9% confidence

Comparison:
           Clepsydra:        0.0 i/s
ActiveSupport::Notifications:        0.0 i/s - 2.47x  (± 0.00) slower
                   with 99.9% confidence
```
