# frozen_string_literal: true

require_relative 'lib/test_queue/version'

Gem::Specification.new do |s|
  s.name = 'test-queue'
  s.version = TestQueue::VERSION
  s.required_ruby_version = '>= 2.7.0'
  s.summary = 'parallel test runner'
  s.description = 'minitest/rspec parallel test runner for CI environments'

  s.homepage = 'https://github.com/tmm1/test-queue'

  s.authors = ['Aman Gupta']
  s.email = 'ruby@tmm1.net'
  s.license = 'MIT'

  s.bindir = 'exe'
  s.executables << 'rspec-queue'
  s.executables << 'minitest-queue'
  s.executables << 'testunit-queue'
  s.executables << 'cucumber-queue'

  s.files = Dir['LICENSE', 'README.md', 'lib/**/*']
  s.metadata['rubygems_mfa_required'] = 'true'
end
