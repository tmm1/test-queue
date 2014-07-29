require 'test_queue/runner'
require 'rspec/core'

case ::RSpec::Core::Version::STRING.to_i
when 2
  require_relative 'rspec2'
when 3
  require_relative 'rspec3'
else
  fail 'requires rspec version 2 or 3'
end

module TestQueue
  class Runner
    class RSpec < Runner
      def initialize
        @rspec = ::RSpec::Core::QueueRunner.new
        super(@rspec.example_groups.sort_by{ |s| -(stats[s.to_s] || 0) })
      end

      def run_worker(iterator)
        @rspec.run_each(iterator).to_i
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
