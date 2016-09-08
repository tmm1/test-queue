load "testlib"

@test "minitest-queue (minitest4) succeeds when all tests pass" {
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue (minitest4) fails when a test fails" {
  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minitest4.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "minitest-queue (minitest5) succeeds when all tests pass" {
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue (minitest5) fails when a test fails" {
  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minitest5.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
  assert_output_contains "1) Failure:"
  assert_output_contains "MiniTestFailure#test_fail"
}

@test "minitest-queue succeeds when all specs pass" {
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "minitest-queue fails when a spec fails" {
  export FAIL=1
  run bundle exec minitest-queue ./test/samples/*_minispec.rb
  [ "$status" -eq 1 ]
  assert_output_contains "1) Failure:"
  assert_output_contains "Meme::when asked about blending possibilities#test_0002_fails"
}

@test "rspec-queue succeeds when all specs pass" {
  run bundle exec rspec-queue ./test/samples
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "rspec-queue fails when a spec fails" {
  export FAIL=1
  run bundle exec rspec-queue ./test/samples
  [ "$status" -eq 1 ]
  assert_output_contains "1) RSpecFailure fails"
  assert_output_contains "Failure/Error: expect(:foo).to eq :bar"
}

@test "cucumber-queue succeeds when all features pass" {
  run bundle exec cucumber-queue test/samples/features
  [ "$status" -eq 0 ]
  assert_output_contains "Starting test-queue master"
}

@test "cucumber-queue fails when a feature fails" {
  export FAIL=1
  run bundle exec cucumber-queue test/samples/features
  [ "$status" -eq 2 ]
  assert_output_contains "Starting test-queue master"
  assert_output_contains "cucumber test/samples/features/bad.feature:2 # Scenario: failure"
  assert_output_contains "cucumber test/samples/features/sample2.feature:26 # Scenario: failure"
}
