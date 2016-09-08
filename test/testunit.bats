load "testlib"

@test "testunit-queue fails when a test fails" {
  run bundle exec testunit-queue ./test/samples/*_testunit.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
}
