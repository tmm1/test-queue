load "testlib"

@test "rspec-queue succeeds when all specs pass" {
  require_gem "rspec" ">= 2.0"

  run bundle exec rspec-queue ./test/samples
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "rspec-queue fails when a spec fails" {
  require_gem "rspec" ">= 2.0"

  export FAIL=1
  run bundle exec rspec-queue ./test/samples
  assert_status 1
  assert_output_contains "1) RSpecFailure fails"
  assert_output_contains "Failure/Error: expect(:foo).to eq :bar"
}
