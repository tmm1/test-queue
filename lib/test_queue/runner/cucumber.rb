require 'cucumber'
require 'cucumber/rspec/disable_option_parser'
require 'cucumber/cli/main'

module Cucumber
  module Ast
    class Features
      attr_accessor :features
    end

    class Feature
      def to_s
        title
      end
    end
  end
end

module TestQueue
  class Runner
    class Cucumber < Runner
      def initialize
        @cli             = ::Cucumber::Cli::Main.new(ARGV.dup)
        @runtime         = ::Cucumber::Runtime.new(@cli.configuration)
        @features_loader = @runtime.send(:features)

        features = @features_loader.is_a?(Array) ? @features_loader : @features_loader.features
        features = features.sort_by { |s| -(stats[s.to_s] || 0) }
        super(features)
      end

      def run_worker(iterator)
        if @features_loader.is_a?(Array)
          @features_loader = iterator
        else
          @features_loader.features = iterator
        end

        @cli.execute!(@runtime)
      end

      def summarize_worker(worker)
        worker.stats.each do |s, val|
          stats[s.to_s] = val
        end

        output                = worker.output.gsub(/\e\[\d+./, '')
        worker.summary        = output.split("\n").grep(/^\d+ (scenarios?|steps?)/).first
        worker.failure_output = output.scan(/^Failing Scenarios:\n(.*)\n\d+ scenarios?/m).join("\n")
      end
    end
  end
end
