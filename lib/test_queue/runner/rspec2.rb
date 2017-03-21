class ::RSpec::Core::ExampleGroup
  def self.failure_count
    examples.map {|e| e.execution_result[:status] == "failed"}.length
  end
end

module RSpec::Core
  class QueueRunner < CommandLine
    def initialize
      super(ARGV)
      @configuration.output_stream = $stdout
      @configuration.error_stream  = $stderr
    end

    def run_each(iterator)
      @configuration.reporter.report(0, @configuration.randomize? ? @configuration.seed : nil) do |reporter|
        begin
          @configuration.run_hook(:before, :suite)
          iterator.map {|g|
            if g.is_a? ::RSpec::Core::Example
              print "    #{g.full_description}: "
              example = g
              g = example.example_group
              ::RSpec.world.filtered_examples.clear
              examples = [example]
              examples.extend(::RSpec::Core::Extensions::Ordered::Examples)
              ::RSpec.world.filtered_examples[g] = examples
            else
              print "    #{g.description}: "
            end
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
