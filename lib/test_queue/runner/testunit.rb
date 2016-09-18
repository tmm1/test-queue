require 'test_queue/runner'

gem 'test-unit'
require 'test/unit'
require 'test/unit/collector/descendant'
require 'test/unit/testresult'
require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'

class Test::Unit::TestSuite
  def run_internal(result, &progress_block)
    @result = result
    run(result, &progress_block)
  end

  def failure_count
    @result.failure_count
  end
end

module TestQueue
  class Runner
    class TestUnit < Runner
      class IteratableTestSuite
        def initialize(iterator)
          @iterator = iterator
        end

        def run(*args, &block)
          @iterator.each do |suite|
            suite.run_internal(*args, &block)
          end
        end

        def size
          0
        end
      end

      def initialize
        @suite = Test::Unit::Collector::Descendant.new.collect
        suites = []
        collect_suites(@suite, suites)
        suites = suites.sort_by{ |s| -(stats.suite_duration(s.to_s) || 0) }
        super(suites)
      end

      def run_worker(iterator)
        suite = IteratableTestSuite.new(iterator)
        res = Test::Unit::UI::Console::TestRunner.new(suite).start
        res.run_count - res.pass_count
      end

      def summarize_worker(worker)
        worker.summary = worker.output.split("\n").grep(/^\d+ tests?/).first
        worker.failure_output = worker.output.scan(/^Failure:\n(.*)\n=======================*/m).join("\n")
      end

      private
      def collect_suites(suite, suites)
        required = suite.tests.any? { |test| test.is_a?(Test::Unit::TestCase) }
        if required
          suites << suite
        else
          suite.tests.each do |suite|
            collect_suites(suite, suites)
          end
        end
      end
    end
  end
end
