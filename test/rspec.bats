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

  assert_output_matches '\[ 1\] +1 example, 0 failures'
  assert_output_matches '\[ 2\] +1 example, 0 failures'
}

@test "TEST_QUEUE_SPLIT_GROUPS does not split unsplittable groups" {
  export TEST_QUEUE_SPLIT_GROUPS=true
  export NOSPLIT=1
  run bundle exec rspec-queue ./test/samples/sample_split_spec.rb
  assert_status 0

  assert_output_contains "2 examples, 0 failures"
  assert_output_contains "0 examples, 0 failures"
}

@test "Use to Shared Exsamples." {
  run bundle exec rspec-queue ./test/samples/sample_use_shared_example1_spec.rb \
                              ./test/samples/sample_use_shared_example2_spec.rb
  assert_status 0

}

