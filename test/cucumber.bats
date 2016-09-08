load "testlib"

setup() {
  require_gem "cucumber" ">= 1.0"
}

@test "cucumber-queue succeeds when all features pass" {
  run bundle exec cucumber-queue test/samples/features --require test/samples/features/step_definitions
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "cucumber-queue fails when a feature fails" {
  export FAIL=1
  run bundle exec cucumber-queue test/samples/features --require test/samples/features/step_definitions
  assert_status 2
  assert_output_contains "Starting test-queue master"
  assert_output_contains "cucumber test/samples/features/bad.feature:2 # Scenario: failure"
  assert_output_contains "cucumber test/samples/features/sample2.feature:26 # Scenario: failure"
}
