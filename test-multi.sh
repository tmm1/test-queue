#!/bin/sh
set -x

# export TEST_QUEUE_VERBOSE=1
TEST_QUEUE_SOCKET=druby://0.0.0.0:12345 bundle exec minitest-queue ./test/sample_minitest5.rb &
sleep 0.1
TEST_QUEUE_RELAY=druby://0.0.0.0:12345  bundle exec minitest-queue ./test/sample_minitest5.rb
wait
