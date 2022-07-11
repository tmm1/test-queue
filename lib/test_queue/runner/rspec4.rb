class ::RSpec::Core::ExampleGroup
  def self.failure_count
    examples.map {|e| e.execution_result.status == "failed"}.length
  end
end

module RSpec::Core
  class QueueRunner < Runner
    def initialize
      options = ConfigurationOptions.new(ARGV)
      super(options)
    end

    def run_specs(iterator)
      @configuration.reporter.report(0) do |reporter|
        @configuration.with_suite_hooks do
          iterator.map { |g|
            start = Time.now
            if g.is_a? ::RSpec::Core::Example
              print "    #{g.full_description}: "
              example = g
              g = example.example_group
              ::RSpec.world.filtered_examples.clear
              ::RSpec.world.filtered_examples[g] = [example]
            else
              print "    #{g.description}: "
            end
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

