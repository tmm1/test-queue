## test-queue

Yet another parallel test runner, built using a centralized queue to ensure
optimal distribution of tests between workers.

Specifically optimized for CI environments: build statistics from each run
are stored locally and used to sort the queue at the beginning of the
next run.

### design

test-queue uses a simple master + pre-fork worker model. The master
exposes a unix domain socket server which workers use to grab tests off
the queue.

```
─┬─ 21232 minitest-queue master
 ├─── 21571 minitest-queue worker [3] - AuthenticationTest
 ├─── 21568 minitest-queue worker [2] - ApiTest
 ├─── 21565 minitest-queue worker [1] - UsersControllerTest
 └─── 21562 minitest-queue worker [0] - UserTest
```

test-queue also has a distributed mode, where additional masters can share
the workload and relay results back to a central master.

### environment variables

- `TEST_QUEUE_WORKERS`: number of workers to use per master (default: all available cores)
- `TEST_QUEUE_VERBOSE`: show results as they are available (default: `0`)
- `TEST_QUEUE_SOCKET`: unix socket `path` (or tcp `address:port` pair) used for communication (default: `/tmp/test_queue_XXXXX.sock`)
- `TEST_QUEUE_RELAY`: relay results back to a central master, specified as tcp `address:port`
- `TEST_QUEUE_STATS`: `path` to cache build stats in-build CI runs (default: `.test_queue_stats`)

### usage

test-queue bundles `minitest-queue` and `rspec-queue` binaries which can be used directly:

```
$ minitest-queue $(find test/ -name \*_test.rb)
$ rspec-queue --format progress spec
```

But the underlying `TestQueue::Runner::MiniTest` and `TestQueue::Runner::Rspec` are
built to be subclassed by your application. I recommend checking a new
executable into your project using one of these superclasses.

```
$ vim script/test-queue
$ chmod +x script/test-queue
$ git add script/test-queue
```

Since test-queue uses `fork(2)` to spawn off workers, you must ensure each worker
runs in an isolated environment. Use the `after_fork` hook with a custom
runner to reset any global state.

``` ruby
#!/usr/bin/env ruby

class MyAppTestRunner < TestQueue::Runner::MiniTest
  def after_fork(num)
    # use separate mysql database (we assume it exists and has the right schema already)
    ActiveRecord::Base.configurations['test']['database'] << num.to_s
    ActiveRecord::Base.establish_connection(:test)

    # use separate redis database
    $redis.client.db = num
    $redis.client.reconnect
  end
end

CustomMiniTestRunner.new.execute
```

### distributed mode

To use distributed mode, the central master must listen on a tcp port. Additional masters can be booted
in relay mode to connect to the central master.

```
$ TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec minitest-queue ./test/sample_test.rb
$ TEST_QUEUE_RELAY=0.0.0.0:12345  bundle exec minitest-queue ./test/sample_test.rb
```

See the [Parameterized Trigger Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin)
for a simple way to do this with jenkins.

### see also

  * https://github.com/Shopify/rails_parallel
  * https://github.com/grosser/parallel_tests
