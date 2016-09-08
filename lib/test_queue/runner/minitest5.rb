require 'test_queue/runner'

module MiniTest
  def self.__run reporter, options
    runnables = Runnable.runnables

    # Run the serial tests first after they complete, run the parallels tests
    # We already sort suites based on its test_order at TestQueue::Runner::Minitest#initialize.
    runnables.map do |runnable|
      if runnable.is_a?(Hash)
        runnable[:suite].run_one_method runnable[:suite], runnable[:test], reporter
      else
        runnable.run reporter, options
      end
    end
  end

  class Runnable
    def failure_count
      failures.length
    end
  end

  class Test
    def self.runnables= runnables
      @@runnables = runnables
    end
  end

  class ProgressReporter
    # Override original method to make test-queue specific output
    def record result
      io.print '    '
      io.print result.class
      io.print ': '
      io.print result.result_code
      io.puts("  <%.3f>" % result.time)
    end
  end

  begin
    require 'minitest/minitest_reporter_plugin'

    class << self
      private
      def total_count(options)
        0
      end
    end
  rescue LoadError
  end
end

module TestQueue
  class Runner
    class MiniTest < Runner
      def initialize
        runnables = ::MiniTest::Test.runnables.reject do |runnable|
          runnable.runnable_methods.empty?
        end

        queue = if self.class.split_groups?
          runnables.map do |runnable|
            runnable.runnable_methods.map do |test|
              {suite: runnable, test: test}
            end
          end.flatten.sort_by do |test_hash|
            -(stats[test_hash.to_s] || 0)
          end
        else
          runnables.sort_by do |runnable|
            -(stats[runnable.to_s] || 0)
          end.partition do |runnable|
            runnable.test_order == :parallel
          end.reverse.flatten
        end

        super(queue)
      end

      def run_worker(iterator)
        ::MiniTest::Test.runnables = iterator
        ::MiniTest.run ? 0 : 1
      end
    end
  end
end
