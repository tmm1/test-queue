require 'minitest/unit'

class MiniTestEqual < MiniTest::Unit::TestCase
  def test_equal
    assert_equal 1, 1
  end
end

30.times do |i|
  Object.const_set("MiniTestSleep#{i}", Class.new(MiniTest::Unit::TestCase) do
    define_method('test_sleep') do
      start = Time.now
      sleep(0.25)
      assert_in_delta Time.now-start, 0.25, 0.02
    end
  end)
end

class MiniTestFailure < MiniTest::Unit::TestCase
  def test_fail
    assert_equal 0, 1
  end
end
