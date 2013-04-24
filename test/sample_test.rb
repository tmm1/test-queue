require 'minitest/unit'

class MiniTestEqual < MiniTest::Unit::TestCase
  def test_equal
    assert_equal 1, 1
  end
end

class MiniTestSleep < MiniTest::Unit::TestCase
  def test_sleep
    start = Time.now
    sleep 0.25
    assert_in_delta Time.now-start, 0.25, 0.02
  end
end

class MiniTestFailure < MiniTest::Unit::TestCase
  def test_fail
    assert_equal 0, 1
  end
end
