begin
  require 'minitest'
  require 'test_queue/runner/minitest5'
rescue LoadError => e
  require 'minitest/unit'
  require 'test_queue/runner/minitest4'
end

module TestQueue
  class Runner
    class MiniTest < Runner
      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s.to_s] = val
        end

        worker.summary = worker.lines.grep(/, \d+ errors?, /).first
        failures  = worker.lines.select{ |line|
          line if (line =~ /^Finished/) ... (line =~ /, \d+ errors?, /)
        }[1..-2]
        worker.failure_output = failures.join("\n") if failures
      end
    end
  end
end
