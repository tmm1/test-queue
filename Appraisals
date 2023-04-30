# frozen_string_literal: true

appraise 'cucumber1-3' do
  gem 'cucumber', '~> 1.3.10'
  # Pin Rake version to Prevent `NoMethodError: undefined method `last_comment'`.
  gem 'rake', '< 11.0'
end

appraise 'cucumber2-4' do
  gem 'cucumber', '~> 2.4.0'
  # Pin Rake version to Prevent `NoMethodError: undefined method `last_comment'`.
  gem 'rake', '< 11.0'
end

appraise 'minitest4' do
  gem 'rake'
  gem 'minitest', '~> 4.7'
end

appraise 'minitest5' do
  gem 'rake'
  gem 'minitest', '5.10.0'
end

appraise 'rspec2' do
  # Pin Rake version to Prevent `NoMethodError: undefined method `last_comment'`.
  gem 'rake', '< 11.0'
  gem 'rspec', '~> 2.99'
end

appraise 'rspec3' do
  gem 'rspec', '~> 3.12'
end

appraise 'rspec4' do
  gem 'rspec', github: 'rspec/rspec-metagem', branch: '4-0-dev'
  gem 'rspec-core', github: 'rspec/rspec-core', branch: '4-0-dev'
  gem 'rspec-expectations', github: 'rspec/rspec-expectations', branch: '4-0-dev'
  gem 'rspec-mocks', github: 'rspec/rspec-mocks', branch: '4-0-dev'
  gem 'rspec-support', github: 'rspec/rspec-support', branch: '4-0-dev'
end

appraise 'testunit' do
  gem 'test-unit'
end
