require 'test_queue/runner'

gem 'test-unit'
require 'test/unit'
require 'test/unit/collector/descendant'
require 'test/unit/testresult'
require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

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
        @suite = Test::Unit::Collector::Descendant.new.collect
        tests = @suite.tests.sort_by{ |s| -(stats[s.to_s] || 0) }
        super(tests)
      end

      def run_worker(iterator)
        @suite.iterator = iterator
        res = Test::Unit::UI::Console::TestRunner.new(@suite).start
        res.run_count - res.pass_count
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s.to_s] = val
        end

        worker.summary = worker.output.split("\n").grep(/^\d+ tests?/).first
        worker.failure_output = worker.output.scan(/^Failure:\n(.*)\n=======================*/m).join("\n")
      end
    end
  end
end
