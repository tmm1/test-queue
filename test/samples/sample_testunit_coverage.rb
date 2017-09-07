require 'test/unit'
require 'simplecov'
SimpleCov.start
require_relative 'coverage'

class TestUnitEqual < Test::Unit::TestCase
  def test_equal
    assert_equal TestClass.new.test, 'test'
  end
end
