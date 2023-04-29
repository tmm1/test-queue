# frozen_string_literal: true

require_relative '../../test_queue'
require 'puppet-lint'

module TestQueue
  class Runner
    class PuppetLint < Runner
      def run_worker(iterator)
        errors = 0
        linter = PuppetLint.new
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

        files    = lines.grep(/^Evaluating/)
        errors   = lines.grep(/^ERROR/)
        warnings = lines.grep(/^WARNING/)

        worker.summary = "#{files.size} files, #{warnings.size} warnings, #{errors.size} errors"
        worker.failure_output = errors.join("\n")
      end
    end
  end
end
