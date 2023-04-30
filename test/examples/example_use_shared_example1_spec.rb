# frozen_string_literal: true

require 'rspec'
require_relative 'example_rspec_helper'

RSpec.describe 'Use SharedExamplesFor test_1' do
  subject { 5 }
  it_behaves_like 'Shared Example'
end
