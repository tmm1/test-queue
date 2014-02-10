require 'test_queue/runner'

module ::MiniTest
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
end

module TestQueue
  class Runner
    class MiniTest < Runner
      def initialize
        tests = ::MiniTest::Test.runnables.sort_by { |s| -(stats[s.to_s] || 0) }
        super(tests)
      end

      def run_worker(iterator)
        ::MiniTest::Test.runnables = iterator
        ::MiniTest.run ? 0 : 1
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s.to_s] = val
        end

        num_tests = worker.lines.grep(/, \d+ errors?, /).first
        failures  = worker.lines.select{ |line|
          line if (line =~ /^Finished/) ... (line =~ /, \d+ errors?, /)
        }[1..-2]
        failures = failures.join("\n") if failures

        [ num_tests, failures ]
      end
    end
  end
end
