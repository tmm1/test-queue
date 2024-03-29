# test-queue

[![Gem Version](https://badge.fury.io/rb/test-queue.svg)](https://rubygems.org/gems/test-queue)
[![CI](https://github.com/tmm1/test-queue/actions/workflows/test.yml/badge.svg)](https://github.com/tmm1/test-queue/actions/workflows/test.yml)

Yet another parallel test runner, built using a centralized queue to ensure
optimal distribution of tests between workers.

Specifically optimized for CI environments: build statistics from each run
are stored locally and used to sort the queue at the beginning of the
next run.

## Usage

test-queue bundles `testunit-queue`, `minitest-queue`, and `rspec-queue` binaries which can be used directly:

```console
$ minitest-queue $(find test/ -name \*_test.rb)
$ rspec-queue --format progress spec
```

But the underlying `TestQueue::Runner::TestUnit`, `TestQueue::Runner::Minitest`, and `TestQueue::Runner::RSpec` are
built to be subclassed by your application. I recommend checking a new
executable into your project using one of these superclasses.

```console
$ vim script/test-queue
$ chmod +x script/test-queue
$ git add script/test-queue
```

Since test-queue uses `fork(2)` to spawn off workers, you must ensure each worker
runs in an isolated environment. Use the `after_fork` hook with a custom
runner to reset any global state.

``` ruby
#!/usr/bin/env ruby

class MyAppTestRunner < TestQueue::Runner::Minitest
  def after_fork(num)
    # Use separate mysql database (we assume it exists and has the right schema already)
    ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: 'primary').database << num.to_s
    ActiveRecord::Base.establish_connection(:test)

    # Use separate redis database
    $redis.client.db = num
    $redis.client.reconnect
  end

  def prepare(concurrency)
    # Create mysql databases exists with correct schema
    concurrency.times do |i|
      # ...
    end

    # If this is a remote master, tell the central master something about us
    @remote_master_message = "Output for remote master 123: http://myhost.com/build/123"
  end

  def around_filter(suite)
    $stats.timing("test.#{suite}.runtime") do
      yield
    end
  end
end

MyAppTestRunner.new.execute
```

## Environment variables

- `TEST_QUEUE_WORKERS`: Number of workers to use per master (default: all available cores)
- `TEST_QUEUE_VERBOSE`: Show results as they are available (default: `0`)
- `TEST_QUEUE_SOCKET`: Unix socket `path` (or TCP `address:port` pair) used for communication (default: `/tmp/test_queue_XXXXX.sock`)
- `TEST_QUEUE_RELAY`: Relay results back to a central master, specified as TCP `address:port`
- `TEST_QUEUE_STATS`: `path` to cache build stats in-build CI runs (default: `.test_queue_stats`)
- `TEST_QUEUE_FORCE`: Comma separated list of suites to run
- `TEST_QUEUE_RELAY_TIMEOUT`: When using distributed builds, the amount of time a remote master will try to reconnect to start work
- `TEST_QUEUE_RELAY_TOKEN`: When using distributed builds, this must be the same on remote masters and the central master for remote masters to be able to connect.
- `TEST_QUEUE_REMOTE_MASTER_MESSAGE`: When using distributed builds, set this on a remote master and it will appear in that master's connection message on the central master.
- `TEST_QUEUE_SPLIT_GROUPS`: Split tests up by example rather than example group. Faster for tests with short setup time such as selenium. RSpec only. Add the `:no_split` tag to `ExampleGroups` you don't want split.

## Design

test-queue uses a simple master + pre-fork worker model. The master
exposes a Unix domain socket server which workers use to grab tests off
the queue.

```console
─┬─ 21232 minitest-queue master
 ├─── 21571 minitest-queue worker [3] - AuthenticationTest
 ├─── 21568 minitest-queue worker [2] - ApiTest
 ├─── 21565 minitest-queue worker [1] - UsersControllerTest
 └─── 21562 minitest-queue worker [0] - UserTest
```

test-queue also has a distributed mode, where additional masters can share
the workload and relay results back to a central master.

## Distributed mode

To use distributed mode, the central master must listen on a TCP port. Additional masters can be booted
in relay mode to connect to the central master. Remote masters must provide a `TEST_QUEUE_RELAY_TOKEN`
to match the central master's.

```console
$ TEST_QUEUE_RELAY_TOKEN=123 TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec minitest-queue ./test/example_test.rb
$ TEST_QUEUE_RELAY_TOKEN=123 TEST_QUEUE_RELAY=0.0.0.0:12345  bundle exec minitest-queue ./test/example_test.rb
$ TEST_QUEUE_RELAY_TOKEN=123 ./test-multi.sh
```

See the [Parameterized Trigger Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin)
for a simple way to do this with Jenkins.

## See also

- https://github.com/Shopify/rails_parallel
- https://github.com/grosser/parallel_tests
