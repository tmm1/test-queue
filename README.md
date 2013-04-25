## test-queue

Yet another parallel test runner, built using a centralized queue to ensure
optimal distribution of tests between workers.

Specifically optimized for CI environments: build statistics from each run
are stored locally and used to sort the queue at the beginning of the
next run.

### usage

```
$ minitest-queue $(find test/ -name \*_test.rb)
$ rspec-queue --format progress spec
```

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

### customization

Since test-queue uses `fork(2)` to spawn off workers, you must ensure each worker
runs in an isolated environment. Use the `after_fork` hook with a custom
runner to reset any global state:

``` ruby
class CustomMiniTestRunner < TestQueue::Runner::MiniTest
  def after_fork(num)
    super

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

### see also

  * https://github.com/Shopify/rails_parallel
  * https://github.com/grosser/parallel_tests
