assert_output_contains() {
  echo "$output" | grep "$@" || {
    echo "Expected to find \"$@\" in:"
    echo "$output"
    return 1
  }
  return 0
}

@test "testunit-queue fails when a test fails" {
  run bundle exec testunit-queue ./test/*_testunit.rb
  [ "$status" -eq 1 ]
  assert_output_contains "Starting test-queue master"
}
