load "testlib"

@test "minitest-queue (minitest4) fails when a test fails" {
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue (minitest5) fails when a test fails" {
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
}

@test "minispec tests pass" {
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "rspec-queue fails when a test fails" {
  run bundle exec rspec-queue test/samples
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
}

@test "cucumber-queue fails when a test fails" {
  run bundle exec cucumber-queue test/samples/features
  [ "$status" -eq 2 ]
  assert_output_contains "Starting test-queue master"
}
