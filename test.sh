#!/bin/sh
set -x

export TEST_QUEUE_WORKERS=2 TEST_QUEUE_VERBOSE=1

bundle install --gemfile=Gemfile-minitest4
bundle exec minitest-queue ./test/*_minitest4.rb
bundle exec minitest-queue ./test/*_minispec.rb

bundle install
bundle exec minitest-queue ./test/*_minitest4.rb
bundle exec minitest-queue ./test/*_minitest5.rb
bundle exec minitest-queue ./test/*_minispec.rb
bundle exec rspec-queue test
bundle exec cucumber-queue

TEST_QUEUE_WORKERS=1 TEST_QUEUE_FORCE="MiniTestSleep21,MiniTestSleep8,MiniTestFailure" bundle exec minitest-queue ./test/*_minitest5.rb
