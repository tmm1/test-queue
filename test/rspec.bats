load "testlib"

setup() {
  require_gem "rspec" ">= 2.0"
}

@test "rspec-queue succeeds when all specs pass" {
  run bundle exec rspec-queue ./test/samples/sample_spec.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "rspec-queue fails when a spec fails" {
  export FAIL=1
  run bundle exec rspec-queue ./test/samples/sample_spec.rb
  assert_status 1
  assert_output_contains "1) RSpecFailure fails"
  assert_output_contains "Failure/Error: expect(:foo).to eq :bar"
}

@test "TEST_QUEUE_SPLIT_GROUPS splits splittable groups" {
  export TEST_QUEUE_SPLIT_GROUPS=true
  run bundle exec rspec-queue ./test/samples/sample_split_spec.rb
  assert_status 0

  # One worker should get tied up with the slow example in the splittable
  # group. The other worker should run the fast example from the splittable
  # group plus the two examples in the unsplittable group.
  assert_output_contains "1 example, 0 failures"
  assert_output_contains "3 examples, 0 failures"
}
