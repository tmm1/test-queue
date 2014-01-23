require 'test_queue/runner'
require 'rspec/core'

module RSpec::Core
  class QueueRunner < CommandLine
    def initialize
      super(ARGV)
      @configuration.output_stream = $stdout
      @configuration.error_stream  = $stderr
    end

    def example_groups
      @options.configure(@configuration)
      @configuration.load_spec_files
      @world.announce_filters
      @world.example_groups
    end

    def run_each(iterator)
      @configuration.reporter.report(0, @configuration.randomize? ? @configuration.seed : nil) do |reporter|
        begin
          @configuration.run_hook(:before, :suite)
          iterator.map {|g|
            print "    #{g.description}: "
            start = Time.now
            ret = g.run(reporter)
            diff = Time.now-start
            puts("  <%.3f>" % diff)

            ret
          }.all? ? 0 : @configuration.failure_exit_code
        ensure
          @configuration.run_hook(:after, :suite)
        end
      end
    end
  end
end

module TestQueue
  class Runner
    class RSpec < Runner
      def initialize
        @rspec = ::RSpec::Core::QueueRunner.new
        super(@rspec.example_groups.sort_by{ |s| -(stats[s.to_s] || 0) })
      end

      def run_worker(iterator)
        @rspec.run_each(iterator)
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s] = val
        end

        summary  = worker.lines.grep(/ examples?, /).first
        failures = worker.output[/^Failures:\n\n(.*)\n^Finished/m, 1]

        [ summary, failures ]
      end
    end
  end
end
