require 'test_queue/runner'
require 'set'
require 'stringio'

class MiniTestQueueRunner < MiniTest::Unit
  def _run_suites(suites, type)
    self.class.output = $stdout

    if defined?(ParallelEach)
      # Ignore its _run_suites implementation since we don't handle it gracefully.
      # If we don't do this #partition is called on the iterator and all suites
      # distributed immediately, instead of picked up as workers are available.
      suites.map { |suite| _run_suite suite, type }
    else
      super
    end
  end

  def _run_anything(*)
    ret = super
    output.puts
    ret
  end

  def _run_suite(suite, type)
    output.print '    '
    output.print suite
    output.print ': '

    start = Time.now
    ret = super
    diff = Time.now - start

    output.puts("  <%.3f>" % diff)
    ret
  end

  self.runner = self.new
  self.output = StringIO.new
end

class MiniTest::Unit::TestCase
  class << self
    attr_accessor :test_suites

    def original_test_suites
      @@test_suites.keys.reject{ |s| s.test_methods.empty? }
    end
  end

  def failure_count
    failures.length
  end
end

module TestQueue
  class Runner
    class MiniTest < Runner
      def initialize
        if ::MiniTest::Unit::TestCase.original_test_suites.any?
          fail "Do not `require` test files. Pass them via ARGV instead and they will be required as needed."
        end
        super(TestFramework::MiniTest.new)
      end

      def run_worker(iterator)
        ::MiniTest::Unit::TestCase.test_suites = iterator
        ::MiniTest::Unit.new.run
      end
    end
  end

  class TestFramework
    class MiniTest < TestFramework
      def all_suite_files
        ARGV
      end

      def suites_from_file(path)
        ::MiniTest::Unit::TestCase.reset
        require File.absolute_path(path)
        ::MiniTest::Unit::TestCase.original_test_suites.map { |suite|
          [suite.name, suite]
        }
      end
    end
  end
end
