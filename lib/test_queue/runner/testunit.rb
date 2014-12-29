require 'test_queue/runner'

gem 'test-unit'
require 'test/unit'
require 'test/unit/runner/console'

module Test
  module Unit
  end
end

module TestQueue
  class Runner
    class TestUnit < Runner
    end
  end
end
