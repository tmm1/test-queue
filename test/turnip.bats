load "testlib"

setup() {
  require_gem "turnip" "~> 4.4"
}

@test "rspec-queue succeeds when all features pass" {
  run bundle exec rspec-queue ./test/examples/features -r turnip/rspec -r ./test/examples/features/turnip_steps/global_steps
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "rspec-queue succeeds when all features and specs pass" {
  run bundle exec rspec-queue ./test/examples -r turnip/rspec -r ./test/examples/features/turnip_steps/global_steps
  assert_status 0
  assert_output_contains "Starting test-queue master"
}

@test "rspec-queue fails when a feature fails" {
  export FAIL=1
  run bundle exec rspec-queue test/examples/features -r turnip/rspec -r ./test/examples/features/turnip_steps/global_steps
  refute_status 0
  assert_output_contains "Starting test-queue master"
  assert_output_contains "test/examples/features/bad.feature:4"
  assert_output_contains "test/examples/features/example2.feature:28"
}

@test "rspec-queue fails when given a missing feature" {
  run bundle exec rspec-queue test/examples/does_not_exist.feature -r turnip/rspec -r ./test/examples/features/turnip_steps/global_steps
  refute_status 0
  assert_output_contains "Aborting: Discovering suites failed."
}

@test "rspec-queue fails when given a malformed feature" {
  [ -f README.md ]
  run bundle exec rspec-queue README.md -r turnip/rspec -r ./test/examples/features/turnip_steps/global_steps

  refute_status 0
  assert_output_matches 'Aborting: Discovering suites failed\.|README\.md: Parser errors:'
}
