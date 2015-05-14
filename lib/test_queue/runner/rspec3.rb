module RSpec::Core
  # RSpec 3.2 introduced:
  unless Configuration.method_defined?(:with_suite_hooks)
    class Configuration
      def with_suite_hooks
        begin
          hook_context = SuiteHookContext.new
          hooks.run(:before, :suite, hook_context)
          yield
        ensure
          hooks.run(:after, :suite, hook_context)
        end
      end
    end
  end

  class QueueRunner < Runner
    def initialize
      options = ConfigurationOptions.new(ARGV)
      super(options)
    end

    def example_groups
      setup($stderr, $stdout)
      @world.ordered_example_groups
    end

    def run_specs(iterator)
      @configuration.reporter.report(@world.ordered_example_groups.count) do |reporter|
        @configuration.with_suite_hooks do
          iterator.map { |g|
            print "    #{g.description}: "
            start = Time.now
            ret = g.run(reporter)
            diff = Time.now-start
            puts("  <%.3f>" % diff)

            ret
          }.all? ? 0 : @configuration.failure_exit_code
        end
      end
    end
    alias_method :run_each, :run_specs
  end
end
