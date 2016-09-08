load "testlib"

@test "minitest-queue succeeds when all tests pass" {
  require_gem "minitest" ">= 4.0"

  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue fails when a test fails" {
  require_gem "minitest" ">= 4.0"

  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "minitest-queue succeeds when all specs pass" {
  require_gem "minitest" ">= 4.0"

  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue fails when a spec fails" {
  require_gem "minitest" ">= 4.0"

  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  [ "$status" -eq 1 ]
  assert_output_contains "1) Failure:"
  assert_output_contains "Meme::when asked about blending possibilities#test_0002_fails"
}
