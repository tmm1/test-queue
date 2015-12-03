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
  class << self
    # give ExampleGroups 'n such a quick/easy way to get at this worker's
    # iterator
    attr_accessor :iterator
  end

  class Runner
    class RSpec < Runner
      SPLIT_GROUPS = ["1", "true"].include?(ENV.fetch("TEST_QUEUE_SPLIT_GROUPS", "0").downcase)

      def initialize
        @rspec = ::RSpec::Core::QueueRunner.new
        super(@rspec.example_groups.sort_by{ |s| -(stats[s.to_s] || 0) })

        if SPLIT_GROUPS
          @group_queues = {}
          @all_groups = {}
          @queue.each do |group|
            group.descendants.each do |subgroup|
              @group_queues[subgroup.to_s] = ::RSpec.world.filtered_examples[subgroup]
              @all_groups[subgroup.to_s] = subgroup
            end
          end
        end
      end

      def has_examples_in_queue?(group)
        @group_queues[group] && @group_queues[group].any?
      end

      def has_descendant_examples_in_queue?(group)
        @all_groups[group].descendants.any? { |group| has_examples_in_queue?(group.to_s) }
      end

      def run_worker(iterator)
        ::TestQueue.iterator = iterator
        @rspec.run_each(iterator).to_i
      end

      # since groups can span runners, we save off the old stats,
      # figure out our new stats across all runners, and merge
      # into the old stats
      def summarize_internal
        @previous_stats = stats
        @stats = {}
        super
      end

      def save_stats
        @stats = @previous_stats.merge(stats)
        super
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s] ||= 0
          stats[s] += val
        end

        worker.summary  = worker.lines.grep(/ examples?, /).first
        worker.failure_output = worker.output[/^Failures:\n\n(.*)\n^Finished/m, 1]
      end

      if SPLIT_GROUPS
        def queue_empty?
          # suite queue can empty out while the very last examples are
          # being worked on; wait till they are done so we don't abandon
          # any live workers
          super && @group_queues.all? { |key, queue| queue.empty? }
        end

        def pop_next
          while item = @queue.shift
            # might have been finished by another worker, so just discard
            # it if it has no more examples
            return item if has_descendant_examples_in_queue?(item.to_s)
          end
        end

        def handle_command(cmd, sock)
          case cmd
          when /^HAS EXAMPLES (\d+)/
            data = sock.read($1.to_i)
            group = Marshal.load(data)
            sock.write Marshal.dump(has_descendant_examples_in_queue?(group))
          when /^POP OWN EXAMPLE (\d+)/
            data = sock.read($1.to_i)
            group = Marshal.load(data)
            if has_examples_in_queue?(group)
              example = @group_queues[group].shift
              sock.write Marshal.dump(example.full_description)
            end
          when /^POP/
            if obj = pop_next
              data = Marshal.dump(obj.to_s)
              sock.write(data)
              # differs from the original in that we immediately put it
              # right back at the end of the queue, so that anyone who
              # finishes early can come help
              @queue << obj unless obj.metadata[:no_split]
            end
          else
            super
          end
        end
      end

      def iterator_factory(*args)
        Iterator.new(*args)
      end

      class Iterator < ::TestQueue::Iterator
        def has_descendant_examples_in_queue?(group)
          group = Marshal.dump(group)
          query("HAS EXAMPLES #{group.bytesize}\n#{group}")
        end

        def pop_example(group)
          group = Marshal.dump(group)
          query("POP OWN EXAMPLE #{group.bytesize}\n#{group}")
        end
      end
    end
  end
end

require_relative 'rspec/split_groups' if TestQueue::Runner::RSpec::SPLIT_GROUPS
