load "testlib"

setup() {
  require_gem "test-unit" ">= 3.0"
}

@test "testunit-queue succeeds when all tests pass" {
  run bundle exec testunit-queue ./test/examples/*_testunit.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "testunit-queue fails when a test fails" {
  export FAIL=1
  run bundle exec testunit-queue ./test/examples/*_testunit.rb
  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "Failure:"
  assert_output_contains "test_fail(TestUnitFailure)"
}

@test "TEST_QUEUE_SPLIT_GROUPS testunit-queue splits splittable sub_test_cases" {
  export TEST_QUEUE_SPLIT_GROUPS=true
  run bundle exec testunit-queue ./test/examples/example_testunit_split.rb
  assert_status 0

  assert_output_matches '\[ 1\] +2 tests,'
  assert_output_matches '\[ 2\] +2 tests,'
}

@test "TEST_QUEUE_SPLIT_GROUPS does not testunit-queue splits splittable sub_test_cases" {
  export TEST_QUEUE_SPLIT_GROUPS=true
  export NOSPLIT=true
  run bundle exec testunit-queue ./test/examples/example_testunit_split.rb
  assert_status 0

  assert_output_matches '\[ .\] +1 tests,'
  assert_output_matches '\[ .\] +3 tests,'
}
