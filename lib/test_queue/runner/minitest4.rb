require 'test_queue/runner'
require 'stringio'

class MiniTestQueueRunner < MiniTest::Unit
  def _run_suites(*)
    self.class.output = $stdout
    super
  end

  def _run_anything(*)
    ret = super
    output.puts
    ret
  end

  def _run_suite(suite, type)
    output.print '    '
    output.print suite
    output.print ': '

    start = Time.now
    ret = super
    diff = Time.now - start

    output.puts("  <%.3f>" % diff)
    ret
  end

  self.runner = self.new
  self.output = StringIO.new
end

class MiniTest::Unit::TestCase
  class << self
    attr_accessor :test_suites

    def original_test_suites
      @@test_suites.keys.reject{ |s| s.test_methods.empty? }
    end
  end
end

module TestQueue
  class Runner
    class MiniTest < Runner
      def initialize
        tests = ::MiniTest::Unit::TestCase.original_test_suites.sort_by{ |s| -(stats[s.to_s] || 0) }
        super(tests)
      end

      def run_worker(iterator)
        ::MiniTest::Unit::TestCase.test_suites = iterator
        ::MiniTest::Unit.new.run
      end
    end
  end
end
