# frozen_string_literal: true

require_relative '../runner'

module Minitest
  def self.__run(reporter, options)
    suites = Runnable.runnables
    suites.map { |suite| suite.run reporter, options }
  end

  class Runnable
    def failure_count
      failures.length
    end
  end

  class Test
    def self.runnables=(runnables)
      @@runnables = runnables
    end

    # Synchronize all tests, even serial ones.
    #
    # Minitest runs serial tests before parallel ones to ensure the
    # unsynchronized serial tests don't overlap the parallel tests. But since
    # the test-queue master hands out tests without actually loading their
    # code, there's no way to know which are parallel and which are serial.
    # Synchronizing serial tests does add some overhead, but hopefully this is
    # outweighed by the speed benefits of using test-queue.
    def _synchronize
      Test.io_lock.synchronize { yield }
    end
  end

  class ProgressReporter
    # Override original method to make test-queue specific output
    def record(result)
      io.print '    '
      io.print result.class
      io.print ': '
      io.print result.result_code
      io.puts('  <%.3f>' % result.time)
    end
  end

  begin
    require 'minitest/minitest_reporter_plugin'

    class << self
      private

      def total_count(_options)
        0
      end
    end
  rescue LoadError
    # noop
  end
end

module TestQueue
  class Runner
    class Minitest < Runner
      def initialize
        @options = ::Minitest.process_args ARGV

        if ::Minitest.respond_to?(:seed)
          ::Minitest.seed = @options[:seed]
          srand ::Minitest.seed
        end

        if ::Minitest::Test.runnables.any? { |r| r.runnable_methods.any? }
          raise 'Do not `require` test files. Pass them via ARGV instead and they will be required as needed.'
        end

        super(TestFramework::Minitest.new)
      end

      def start_master
        puts "Run options: #{@options[:args]}\n\n"

        super
      end

      def run_worker(iterator)
        ::Minitest::Test.runnables = iterator
        ::Minitest.run ? 0 : 1
      end
    end
    MiniTest = Minitest # For compatibility with test-queue 0.7.0 and earlier.
  end

  class TestFramework
    class Minitest < TestFramework
      def all_suite_files
        ARGV
      end

      def suites_from_file(path)
        ::Minitest::Test.reset
        require File.absolute_path(path)
        ::Minitest::Test.runnables
                        .reject { |s| s.runnable_methods.empty? }
                        .map { |s| [s.name, s] }
      end
    end
    MiniTest = Minitest # For compatibility with test-queue 0.7.0 and earlier.
  end
end
