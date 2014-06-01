require 'test_queue/runner'
require 'rspec/core'

module RSpec::Core
  class QueueRunner < Runner
    def initialize
      options = ::RSpec::Core::ConfigurationOptions.new(ARGV)
      super(options)
    end

    def example_groups
      setup($stderr, $stdout)
      @world.ordered_example_groups
    end

    def run_specs(iterator)
      @configuration.reporter.report(@world.ordered_example_groups.count) do |reporter|
        begin
          hook_context = SuiteHookContext.new
          @configuration.hooks.run(:before, :suite, hook_context)

          iterator.map { |g|
            print "    #{g.description}: "
            start = Time.now
            ret = g.run(reporter)
            diff = Time.now-start
            puts("  <%.3f>" % diff)

            ret
          }.all? ? 0 : @configuration.failure_exit_code
        ensure
          @configuration.hooks.run(:after, :suite, hook_context)
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
        @rspec.run_specs(iterator).to_i
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s] = val
        end

        worker.summary  = worker.lines.grep(/ examples?, /).first
        worker.failure_output = worker.output[/^Failures:\n\n(.*)\n^Finished/m, 1]
      end
    end
  end
end
