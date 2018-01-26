load "testlib"

setup() {
  rm -rf coverage
  require_gem "test-unit" ">= 3.0"
}

@test "testunit-queue succeeds when all tests pass" {
  run bundle exec testunit-queue ./test/samples/*_testunit.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "testunit-queue fails when a test fails" {
  export FAIL=1
  run bundle exec testunit-queue ./test/samples/*_testunit.rb
  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "Failure:"
  assert_output_contains "test_fail(TestUnitFailure)"
}

@test "testunit-queue supports coverage" {
  run bundle exec ruby -r simplecov ./bin/testunit-queue ./test/samples/sample_testunit_coverage.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}
