require 'rspec'
require_relative 'sample_rspec_helper'

describe 'Use SharedExcaplesFor test_1' do
  subject { 5 }
  it_behaves_like 'Sample Example'
end

