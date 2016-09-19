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

  def failure_count
    (@iterator || @tests).map {|t| t.instance_variable_get(:@_result).failure_count}.inject(0, :+)
  end
end

module TestQueue
  class Runner
    class TestUnit < Runner
      def initialize
        if Test::Unit::Collector::Descendant.new.collect.tests.any?
          fail "Do not `require` test files. Pass them via ARGV instead and they will be required as needed."
        end
        super(TestFramework::TestUnit.new)
      end

      def run_worker(iterator)
        @suite = Test::Unit::TestSuite.new("specified by test-queue master")
        @suite.iterator = iterator
        res = Test::Unit::UI::Console::TestRunner.new(@suite).start
        res.run_count - res.pass_count
      end

      def summarize_worker(worker)
        worker.summary = worker.output.split("\n").grep(/^\d+ tests?/).first
        worker.failure_output = worker.output.scan(/^Failure:\n(.*)\n=======================*/m).join("\n")
      end
    end
  end

  class TestFramework
    class TestUnit < TestFramework
      def all_suite_files
        ARGV
      end

      def suites_from_file(path)
        Test::Unit::TestCase::DESCENDANTS.clear
        require File.absolute_path(path)
        Test::Unit::Collector::Descendant.new.collect.tests.map { |suite|
          [suite.name, suite]
        }
      end
    end
  end
end
