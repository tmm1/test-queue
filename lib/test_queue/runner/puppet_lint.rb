require 'test_queue'
require 'puppet-lint'

module TestQueue
  class Runner
    class PuppetLint < Runner
      def run_worker(iterator)
        errors = 0
        linter =  PuppetLint.new
        iterator.each do |file|
          puts "Evaluating #{file}"
          linter.file = file
          linter.run
          errors += 1 if linter.errors?
        end
        errors
      end

      def summarize_worker(worker)
        lines = worker.lines

        files    = lines.select{ |line| line =~ /^Evaluating/ }
        errors   = lines.select{ |line| line =~ /^ERROR/ }
        warnings = lines.select{ |line| line =~ /^WARNING/ }

        worker.summary = "#{files.size} files, #{warnings.size} warnings, #{errors.size} errors"
        worker.failure_output = errors.join("\n")
      end
    end
  end
end
