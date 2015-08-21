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
        @split_groups = ENV['TEST_QUEUE_SPLIT_GROUPS'] && ENV['TEST_QUEUE_SPLIT_GROUPS'].strip.downcase == 'true'
        if @split_groups
          groups = @rspec.example_groups
          groups_to_split, groups_to_keep = [], []
          groups.each do |group|
            (group.metadata[:no_split] ? groups_to_keep : groups_to_split) << group
          end
          queue = groups_to_split.map(&:descendant_filtered_examples).flatten
          queue.concat groups_to_keep
          queue.sort_by!{ |s| -(stats[s.id] || 0) }
        else
          queue = @rspec.example_groups.sort_by{ |s| -(stats[s.to_s] || 0) }
        end

        super(queue)
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
