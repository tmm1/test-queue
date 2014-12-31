require 'test_queue/runner'

gem 'test-unit'
require 'test/unit'
require 'test/unit/collector/descendant'
require 'test/unit/testresult'
require 'test/unit/testsuite'
require 'test/unit/testcase'

class Test::Unit::TestSuite
  attr_accessor :iterator

  def run(result, &progress_block)
    @start_time = Time.now
    yield(STARTED, name)
    yield(STARTED_OBJECT, self)
    run_startup(result)
    (@iterator || @tests).each do |test|
      @n_tests += test.size
      run_test(test, result, &progress_block)
      @passed = false unless test.passed?
    end
    run_shutdown(result)
  ensure
    @elapsed_time = Time.now - @start_time
    yield(FINISHED, name)
    yield(FINISHED_OBJECT, self)
  end
end

module TestQueue
  class Runner
    class TestUnit < Runner
      def initialize
        c = Test::Unit::Collector::Descendant.new
        @suite = c.collect
        tests = @suite.tests
        super(tests)
      end

      def run_worker(iterator)
        @suite.iterator = iterator
        @suite.run(res = Test::Unit::TestResult.new) do |status, obj|
        end
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s.to_s] = val
        end

        p worker.output
      end
    end
  end
end
