require 'minitest/autorun'

require 'simplecov'
SimpleCov.start
require_relative 'coverage'

class MiniTestEqual < MiniTest::Test
  def test_equal
    assert_equal TestClass.new.test, 'test'
  end
end
