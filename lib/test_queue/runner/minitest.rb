# frozen_string_literal: true

require 'minitest'

raise 'requires Minitest version 5' unless Minitest::VERSION.to_i == 5

require_relative '../runner/minitest5'

module TestQueue
  class Runner
    class Minitest < Runner
      def summarize_worker(worker)
        worker.summary = worker.lines.grep(/, \d+ errors?, /).first
        failures = worker.lines.select { |line|
          line if (line =~ /^Finished/) ... (line =~ /, \d+ errors?, /)
        }[1..-2]
        worker.failure_output = failures.join("\n") if failures
      end
    end
  end
end
