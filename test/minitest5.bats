load "testlib"

setup() {
  require_gem "minitest" ">= 5.0"
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

@test "multi-master succeeds when all tests pass" {
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec minitest-queue ./test/samples/sample_minitest5.rb &
  sleep 0.1
  TEST_QUEUE_RELAY=0.0.0.0:12345 run bundle exec minitest-queue ./test/samples/sample_minitest5.rb
  wait

  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "multi-master fails when a test fails" {
  export FAIL=1
  export TEST_QUEUE_RELAY_TOKEN=$(date | cksum | cut -d' ' -f1)
  TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec minitest-queue ./test/samples/sample_minitest5.rb &
  sleep 0.1
  TEST_QUEUE_RELAY=0.0.0.0:12345 run bundle exec minitest-queue ./test/samples/sample_minitest5.rb
  wait

  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}
