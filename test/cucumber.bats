load "testlib"

SCRATCH=tmp/cucumber-tests

setup() {
  require_gem "cucumber" ">= 1.0"
  rm -rf $SCRATCH
  mkdir -p $SCRATCH
}

teardown() {
  rm -rf $SCRATCH
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

@test "cucumber-queue fails when given a missing feature" {
  run bundle exec cucumber-queue test/samples/does_not_exist.feature --require test/samples/features/step_definitions
  assert_status 1
  assert_output_contains "Aborting: Discovering suites failed."
}

@test "cucumber-queue fails when given a malformed feature" {
  [ -f README.md ]
  run bundle exec cucumber-queue README.md --require test/samples/features/step_definitions

  # Cucumber 1 and 2 fail in different ways.
  refute_status 0
  assert_output_matches 'Aborting: Discovering suites failed\.|README\.md: Parser errors:'
}

@test "cucumber-queue handles test file being deleted" {
  cp test/samples/features/*.feature $SCRATCH

  run bundle exec cucumber-queue $SCRATCH --require test/samples/features/step_definitions
  assert_status 0
  assert_output_matches "Feature: Foobar$"

  rm $SCRATCH/sample.feature

  run bundle exec cucumber-queue $SCRATCH --require test/samples/features/step_definitions
  assert_status 0
  refute_output_matches "Feature: Foobar$"
}
