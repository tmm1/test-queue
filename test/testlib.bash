assert_output_contains() {
  echo "$output" | grep "$@" || {
    echo "Expected to find \"$@\" in:"
    echo "$output"
    return 1
  }
  return 0
}
