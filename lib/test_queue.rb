if !IO.respond_to?(:binread)
  class << IO
    alias :binread :read
  end
end

require 'test_queue/iterator'
require 'test_queue/runner'
