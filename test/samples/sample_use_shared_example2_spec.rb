require 'rspec'
require_relative 'sample_rspec_helper'

RSpec::describe 'Use SharedExamplesFor test_2' do
  subject { 5 }
  it_behaves_like 'Sample Example'
end
