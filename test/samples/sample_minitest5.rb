require 'minitest/autorun'

class MiniTestEqual < MiniTest::Test
  def test_equal
    assert_equal 1, 1
  end
end

30.times do |i|
  Object.const_set("MiniTestSleep#{i}", Class.new(MiniTest::Test) do
    define_method('test_sleep') do
      start = Time.now
      sleep_time = 0.01 * i
      sleep(sleep_time)
      assert_in_delta Time.now-start, sleep_time, 0.02
    end
  end)
end

if ENV["FAIL"]
  class MiniTestFailure < MiniTest::Test
    def test_fail
      assert_equal 0, 1
    end
  end
end
