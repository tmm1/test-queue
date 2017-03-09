load "testlib"

SCRATCH=tmp/minitest5-tests

setup() {
  require_gem "minitest" ">= 5.0"
  rm -rf $SCRATCH
  mkdir -p $SCRATCH
}

teardown() {
  rm -rf $SCRATCH
}

@test "minitest-queue (minitest5) succeeds when all tests pass" {
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue (minitest5) fails when a test fails" {
  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "TEST_QUEUE_FORCE whitelists certain tests" {
  export TEST_QUEUE_WORKERS=1 TEST_QUEUE_FORCE="MiniTestSleep21,MiniTestSleep8"
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
  assert_output_contains "MiniTestSleep21"
  assert_output_contains "MiniTestSleep8"
  refute_output_contains "MiniTestSleep9"
}

assert_test_queue_force_ordering() {
  run bundle exec minitest-queue "$@"
  assert_status 0
  assert_output_contains "Starting test-queue master"

  # Turn the list of suites that were run into a comma-separated list. Input
  # looks like:
  #     SuiteName: .  <0.001>
  actual_tests=$(echo "$output" | \
                 egrep '^    .*: \.+  <' | \
                 sed -E -e 's/^    (.*): \.+.*/\1/' | \
                 tr '\n' ',' | \
                 sed -e 's/,$//')
  assert_equal "$TEST_QUEUE_FORCE" "$actual_tests"
}

@test "TEST_QUEUE_FORCE ensures test ordering" {
  export TEST_QUEUE_WORKERS=1 TEST_QUEUE_FORCE="Meme::when asked about cheeseburgers,MiniTestEqual"

  # Without stats file
  rm -f .test_queue_stats
  assert_test_queue_force_ordering ./test/samples/sample_minitest5.rb ./test/samples/sample_minispec.rb
  rm -f .test_queue_stats
  assert_test_queue_force_ordering ./test/samples/sample_minispec.rb ./test/samples/sample_minitest5.rb

  # With stats file
  assert_test_queue_force_ordering ./test/samples/sample_minitest5.rb ./test/samples/sample_minispec.rb
  assert_test_queue_force_ordering ./test/samples/sample_minispec.rb ./test/samples/sample_minitest5.rb
}

@test "minitest-queue fails if TEST_QUEUE_FORCE specifies nonexistent tests" {
  export TEST_QUEUE_WORKERS=1 TEST_QUEUE_FORCE="MiniTestSleep21,DoesNotExist"
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  assert_status 1
  assert_output_contains "Failed to discover DoesNotExist specified in TEST_QUEUE_FORCE"
}

@test "multi-master central master succeeds when all tests pass" {
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  export SLEEP_AS_RELAY=1
  TEST_QUEUE_RELAY=0.0.0.0:12345 bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb || true &
  sleep 0.1
  TEST_QUEUE_SOCKET=0.0.0.0:12345 run bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb
  wait

  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "multi-master remote master succeeds when all tests pass" {
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  export SLEEP_AS_MASTER=1
  TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb || true &
  sleep 0.1
  TEST_QUEUE_RELAY=0.0.0.0:12345 run bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb
  wait

  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "multi-master central master fails when a test fails" {
  export FAIL=1
  export SLEEP_AS_RELAY=1
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  TEST_QUEUE_RELAY=0.0.0.0:12345 bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb || true &
  sleep 0.1
  TEST_QUEUE_SOCKET=0.0.0.0:12345 run bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb
  wait

  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "multi-master remote master fails when a test fails" {
  export FAIL=1
  export SLEEP_AS_MASTER=1
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb || true &
  sleep 0.1
  TEST_QUEUE_RELAY=0.0.0.0:12345 run bundle exec ruby ./test/sleepy_runner.rb ./test/samples/sample_minitest5.rb
  wait

  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "multi-master central master prints out remote master messages" {
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  TEST_QUEUE_RELAY=0.0.0.0:12345 TEST_QUEUE_REMOTE_MASTER_MESSAGE="hello from remote master" bundle exec minitest-queue ./test/samples/sample_minitest5.rb &
  TEST_QUEUE_SOCKET=0.0.0.0:12345 run bundle exec minitest-queue ./test/samples/sample_minitest5.rb
  wait

  assert_status 0
  assert_output_contains "hello from remote master"
}

@test "recovers from child processes dying in an unorderly way" {
  export KILL=1
  run bundle exec minitest-queue ./test/samples/sample_minitest5.rb
  assert_status 1
  assert_output_contains "SIGKILL (signal 9)"
}

@test "minitest-queue fails when TEST_QUEUE_WORKERS is <= 0" {
  export TEST_QUEUE_WORKERS=0
  run bundle exec minitest-queue ./test/samples/sample_minitest5.rb
  assert_status 1
  assert_output_contains "Worker count (0) must be greater than 0"
}

@test "minitest-queue fails when given a missing test file" {
  run bundle exec minitest-queue ./test/samples/does_not_exist.rb
  assert_status 1
  assert_output_contains "Aborting: Discovering suites failed"
}

@test "minitest-queue fails when given a malformed test file" {
  [ -f README.md ]
  run bundle exec minitest-queue README.md
  assert_status 1
  assert_output_contains "Aborting: Discovering suites failed"
}

@test "minitest-queue handles test file being deleted" {
  cp test/samples/sample_mini{test5,spec}.rb $SCRATCH

  run bundle exec minitest-queue $SCRATCH/*
  assert_status 0
  assert_output_contains "Meme::when asked about blending possibilities"

  rm $SCRATCH/sample_minispec.rb

  run bundle exec minitest-queue $SCRATCH/*
  assert_status 0
  refute_output_contains "Meme::when asked about blending possibilities"
}

@test "minitest-queue handles suites changing inside a file" {
  cp test/samples/sample_minispec.rb $SCRATCH

  run bundle exec minitest-queue $SCRATCH/sample_minispec.rb
  assert_status 0
  assert_output_contains "Meme::when asked about blending possibilities"

  sed -i'' -e 's/Meme/Meme2/g' $SCRATCH/sample_minispec.rb

  run bundle exec minitest-queue $SCRATCH/sample_minispec.rb
  assert_status 0
  assert_output_contains "Meme2::when asked about blending possibilities"
}
