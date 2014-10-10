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
