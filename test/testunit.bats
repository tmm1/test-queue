load "testlib"

@test "testunit-queue succeeds when all tests pass" {
  require_gem "test-unit" ">= 3.0"

  run bundle exec testunit-queue ./test/samples/*_testunit.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "testunit-queue fails when a test fails" {
  require_gem "test-unit" ">= 3.0"

  export FAIL=1
  run bundle exec testunit-queue ./test/samples/*_testunit.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
  assert_output_contains "Failure:"
  assert_output_contains "test_fail(TestUnitFailure)"
}
