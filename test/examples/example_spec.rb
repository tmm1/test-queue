# frozen_string_literal: true

require 'rspec'

RSpec.describe 'RSpecEqual' do
  it 'checks equality' do
    expect(1).to eq 1
  end
end

30.times do |i|
  RSpec.describe "RSpecSleep(#{i})" do
    it 'sleeps' do
      start = Time.now
      sleep(0.25)
      expect(Time.now - start).to be_within(0.02).of(0.25)
    end
  end
end

if ENV['FAIL']
  RSpec.describe 'RSpecFailure' do
    it 'fails' do
      expect(:foo).to eq :bar
    end
  end
end
