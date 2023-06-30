# frozen_string_literal: true

require 'test/unit'

class SplittableTestCase < Test::Unit::TestCase
  def wait
    # Sleep longer in CI to make the distribution of examples across workers
    # more deterministic.
    if ENV['CI']
      sleep(5)
    else
      sleep(1)
    end
  end

  sub_test_case 'splittable sub_test_case 1' do
    test 'test 1' do
      wait
      assert true
    end

    sub_test_case 'splittable sub_test_case 2' do
      attribute :no_split, !!ENV['NOSPLIT'], keep: true

      test 'test 3' do
        wait
        assert true
      end

      test 'test 4' do
        wait
        assert true
      end

      test 'test 5' do
        wait
        assert true
      end
    end
  end
end
