# frozen_string_literal: true

require 'minitest/unit'

class MinitestEqual < MiniTest::Unit::TestCase
  def test_equal
    assert_equal 1, 1
  end
end

30.times do |i|
  Object.const_set("MinitestSleep#{i}", Class.new(Minitest::Unit::TestCase) do
    define_method(:test_sleep) do
      start = Time.now
      sleep(0.25)
      assert_in_delta Time.now - start, 0.25, 0.02
    end
  end)
end

if ENV['FAIL']
  class MinitestFailure < MiniTest::Unit::TestCase
    def test_fail
      assert_equal 0, 1
    end
  end
end
