require 'rspec'
require 'simplecov'
SimpleCov.start
require_relative 'coverage'

describe TestClass do
  it 'returns test' do
    expect(TestClass.new.test).to eq('test')
  end
end
