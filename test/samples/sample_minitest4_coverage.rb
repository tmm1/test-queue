require 'minitest/unit'

require 'simplecov'
SimpleCov.start
require_relative 'coverage'

class MiniTestEqual < MiniTest::Unit::TestCase
  def test_equal
    assert_equal(Test.new.test, 'test')
  end
end
