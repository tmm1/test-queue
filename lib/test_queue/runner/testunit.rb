# frozen_string_literal: true

require_relative '../runner'

gem 'test-unit'
require 'test/unit'
require 'test/unit/collector/load'
require 'test/unit/ui/console/testrunner'

module TestQueue
  class Runner
    class TestUnit < Runner
      class TestSuite < ::Test::Unit::TestSuite
        def initialize(name, iterator)
          super(name)
          @tests = IteratorWrapper.new(iterator)
        end

        def run(*)
          @started = true
          super
        end

        def size
          return 0 unless @started

          super
        end
      end

      class IteratorWrapper
        def initialize(iterator)
          @generator = Fiber.new do
            iterator.each do |test|
              Fiber.yield(test)
            end
          end
        end

        def shift
          @generator.resume
        rescue FiberError
          nil
        end

        def each
          while (test = shift)
            yield(test)
          end
        end
      end

      def initialize
        super(TestFramework::TestUnit.new)
      end

      def run_worker(iterator)
        @suite = TestSuite.new('specified by test-queue master', iterator)
        res = Test::Unit::UI::Console::TestRunner.new(@suite).start
        res.run_count - res.pass_count
      end

      def summarize_worker(worker)
        worker.summary = worker.output.split("\n").grep(/^\d+ tests?/).first
        worker.failure_output = worker.output.scan(/^Failure:[^\n]*\n(.*?)\n=======================*/m).join("\n")
      end
    end
  end

  class TestFramework
    class TestUnit < TestFramework
      def all_suite_files
        ARGV
      end

      def suites_from_file(path)
        test_suite = Test::Unit::Collector::Load.new.collect(path)
        return [] unless test_suite
        return test_suite.tests.map { [_1.name, _1] } unless split_groups?

        split_groups(test_suite)
      end

      def split_groups?
        return @split_groups if defined?(@split_groups)

        @split_groups = ENV['TEST_QUEUE_SPLIT_GROUPS'] && ENV['TEST_QUEUE_SPLIT_GROUPS'].strip.downcase == 'true'
      end

      def split_groups(test_suite, groups = [])
        unless splittable?(test_suite)
          groups << [test_suite.name, test_suite]
          return groups
        end

        test_suite.tests.each do |suite|
          if suite.is_a?(Test::Unit::TestSuite)
            split_groups(suite, groups)
          else
            groups << [suite.name, suite]
          end
        end
        groups
      end

      def splittable?(test_suite)
        test_suite.tests.none? do |test|
          test.is_a?(Test::Unit::TestCase) && test[:no_split]
        end
      end
    end
  end
end
