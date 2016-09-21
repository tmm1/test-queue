# Skip this test unless the bundle contains a gem matching the required
# version. Example:
#
#   require_gem "minitest" "~> 5.3"
require_gem() {
  name=$1
  requirement=$2

  set +e
  version=$(bundle exec ruby - <<RUBY
    spec = Gem.loaded_specs['$name']
    exit unless spec
    puts spec.version
    exit Gem::Dependency.new('$name', '$requirement').match?(spec)
RUBY
)
  result=$?
  set -e

  if [ "$version" = "" ]; then
    skip "$name is not installed"
  elif [ $result -ne 0 ]; then
    skip "$name $version is not $requirement"
  fi
}

assert_status() {
  expected=$1
  [ "$status" -eq "$expected" ] || {
    echo "Expected status to be $expected but was $status. Full output:"
    echo "$output"
    return 1
  }
  return 0
}

refute_status() {
  expected=$1
  [ "$status" -ne "$expected" ] || {
    echo "Expected status not to be $expected. Full output:"
    echo "$output"
    return 1
  }
  return 0
}

assert_output_contains() {
  echo "$output" | fgrep --quiet "$@" || {
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

assert_output_matches() {
  echo "$output" | egrep --quiet "$@" || {
    echo "Expected to \"$@\" to match within:"
    echo "$output"
    return 1
  }
  return 0
}

refute_output_matches() {
  assert_output_matches "$@" && {
    echo "Expected \"$@\" not to match within:"
    echo "$output"
    return 1
  }
  return 0
}

assert_equal() {
  [ "$1" = "$2" ] || {
    echo "Expected \"$1\" to equal \"$2\""
    return 1
  }
  return 0
}
