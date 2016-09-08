load "testlib"

@test "cucumber-queue succeeds when all features pass" {
  require_gem "cucumber" ">= 1.0"

  run bundle exec cucumber-queue test/samples/features
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "cucumber-queue fails when a feature fails" {
  require_gem "cucumber" ">= 1.0"

  export FAIL=1
  run bundle exec cucumber-queue test/samples/features
  assert_status 2
  assert_output_contains "Starting test-queue master"
  assert_output_contains "cucumber test/samples/features/bad.feature:2 # Scenario: failure"
  assert_output_contains "cucumber test/samples/features/sample2.feature:26 # Scenario: failure"
}
