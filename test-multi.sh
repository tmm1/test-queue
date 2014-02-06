#!/bin/sh
set -x

TEST_QUEUE_SOCKET=0.0.0.0:12345 bundle exec minitest-queue ./test/sample_test.rb &
sleep 0.1
TEST_QUEUE_RELAY=0.0.0.0:12345  bundle exec minitest-queue ./test/sample_test.rb
wait
