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
    alias_method :run_each, :run_specs
  end
end
