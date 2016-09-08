assert_output_contains() {
  echo "$output" | grep -q "$@" || {
    echo "Expected to find \"$@\" in:"
    echo "$output"
    return 1
  }
  return 0
}

refute_output_contains() {
  assert_output_contains "$@" && {
    echo "Expected not to find \"$@\" in:"
    echo "$output"
    return 1
  }
  return 0
}
