begin
  require 'minitest'
  require_relative '../runner/minitest5'
rescue LoadError => e
  require 'minitest/unit'
  require_relative '../runner/minitest4'
end

module TestQueue
  class Runner
    class Minitest < Runner
      def summarize_worker(worker)
        worker.summary = worker.lines.grep(/, \d+ errors?, /).first
        failures  = worker.lines.select{ |line|
          line if (line =~ /^Finished/) ... (line =~ /, \d+ errors?, /)
        }[1..-2]
        worker.failure_output = failures.join("\n") if failures
      end
    end
  end
end
