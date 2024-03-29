# frozen_string_literal: true

require_relative '../../test_queue'
require_relative '../runner'

module TestQueue
  class Runner
    class Example < Runner
      def initialize(args)
        super(TestFramework::Example.new(args))
      end

      def spawn_workers
        puts "Spawning #{@concurrency} workers"
        super
      end

      def after_fork(num)
        puts "  -- worker #{num} booted as pid #{$$}"
        super
      end

      def run_worker(iterator)
        iterator.inject(0) do |sum, item|
          puts "  #{item.inspect}"
          sum + item.to_i
        end
      end

      def summarize_worker(worker)
        worker.summary = worker.output.scan(/^\s*(\d+)/).join(', ')
        worker.failure_output = ''
      end
    end
  end

  class TestFramework
    class Example < TestFramework
      def initialize(args)
        super()

        @args = args.map(&:to_s)
      end

      def all_suite_files
        @args
      end

      def suites_from_file(_path)
        @args.map { |i| [i, i] }
      end
    end
  end
end

if __FILE__ == $0
  TestQueue::Runner::Example.new(Array(1..10)).execute
end

__END__

Spawning 4 workers
  -- worker 0 booted as pid 40406
  -- worker 1 booted as pid 40407
  -- worker 2 booted as pid 40408
  -- worker 3 booted as pid 40409

==> Starting ruby test-queue worker [1] (40407)

  2
  5
  8

==> Starting ruby test-queue worker [3] (40409)


==> Starting ruby test-queue worker [2] (40408)

  3
  6
  9

==> Starting ruby test-queue worker [0] (40406)

  1
  4
  7
  10

==> Summary

    [1]                                                 2, 5, 8      in 0.0024s      (pid 40407 exit 15)
    [3]                                                              in 0.0036s      (pid 40409 exit 0)
    [2]                                                 3, 6, 9      in 0.0038s      (pid 40408 exit 18)
    [0]                                             1, 4, 7, 10      in 0.0044s      (pid 40406 exit 22)
