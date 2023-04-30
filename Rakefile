# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: [:setup, :rubocop, :spec, :feature]

task :setup do
  sh 'script/bootstrap' unless File.exist?("#{Dir.pwd}/vendor/bats/bin/bats")
end

task :feature do
  sh 'TEST_QUEUE_WORKERS=2 TEST_QUEUE_VERBOSE=1 vendor/bats/bin/bats test'
end
