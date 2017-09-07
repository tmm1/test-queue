require 'rspec'
require 'simplecov'
SimpleCov.start
require_relative 'coverage'

describe Test do
  it 'returns test' do
    expect(Test.new.test).to eq('test')
  end
end
