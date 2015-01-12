module TestQueue
  class Iterator
    attr_reader :stats

    def initialize(master, suites, filter=nil)
      @done = false
      @stats = {}
      @procline = $0
      @suites = suites
      @filter = filter
      @master = master
    end

    def each
      fail "already used this iterator. previous caller: #@done" if @done

      while suite = @suites[@master.pop]
        $0 = "#{@procline} - #{suite.respond_to?(:description) ? suite.description : suite}"
        start = Time.now
        if @filter
          @filter.call(suite){ yield suite }
        else
          yield suite
        end
        @stats[suite.to_s] = Time.now - start
      end
    rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
    ensure
      @done = caller.first
      File.open("/tmp/test_queue_worker_#{$$}_stats", "wb") do |f|
        f.write Marshal.dump(@stats)
      end
    end

    include Enumerable

    def empty?
      false
    end
  end
end
