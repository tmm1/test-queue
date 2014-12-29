#!/bin/sh
set -x

export TEST_QUEUE_WORKERS=2 TEST_QUEUE_VERBOSE=1

export BUNDLE_GEMFILE=Gemfile-testunit
bundle install
bundle exec testunit-queue ./test/*_testunit.rb

export BUNDLE_GEMFILE=Gemfile-minitest4
bundle install
bundle exec minitest-queue ./test/*_minitest4.rb
bundle exec minitest-queue ./test/*_minispec.rb

export BUNDLE_GEMFILE=Gemfile
bundle install
bundle exec minitest-queue ./test/*_minitest4.rb
bundle exec minitest-queue ./test/*_minitest5.rb
bundle exec minitest-queue ./test/*_minispec.rb
bundle exec rspec-queue test
bundle exec cucumber-queue

TEST_QUEUE_WORKERS=1 TEST_QUEUE_FORCE="MiniTestSleep21,MiniTestSleep8,MiniTestFailure" bundle exec minitest-queue ./test/*_minitest5.rb
