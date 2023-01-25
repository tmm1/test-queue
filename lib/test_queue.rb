if !IO.respond_to?(:binread)
  class << IO
    alias :binread :read
  end
end

require_relative 'test_queue/iterator'
require_relative 'test_queue/runner'
