load "testlib"

setup() {
  require_gem "minitest" ">= 4.0"
}

@test "minitest-queue succeeds when all tests pass" {
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue fails when a test fails" {
  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  assert_status 1
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "minitest-queue succeeds when all specs pass" {
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue fails when a spec fails" {
  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  assert_status 1
  assert_output_contains "1) Failure:"
  assert_output_contains "Meme::when asked about blending possibilities#test_0002_fails"
}
