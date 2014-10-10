module TestQueue
  class Iterator
    attr_reader :stats, :client

    def initialize(client, suites, filter=nil)
      @done = false
      @stats = {}
      @procline = $0
      @client = client
      @suites = suites
      @filter = filter
    end

    def each
      fail "already used this iterator. previous caller: #@done" if @done

      while true
        item = client.pop
        break if item.nil? || item.empty?
        suite = @suites[item]

        $0 = "#{@procline} - #{suite.respond_to?(:description) ? suite.description : suite}"
        start = Time.now
        if @filter
          @filter.call(suite){ yield suite }
        else
          yield suite
        end
        @stats[suite.to_s] = Time.now - start
      end

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
