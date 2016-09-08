load "testlib"

@test "minitest-queue fails when a test fails" {
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
}

@test "minispec tests pass" {
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}
