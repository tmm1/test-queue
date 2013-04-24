module TestQueue
  class Iterator
    attr_reader :stats

    def initialize(sock)
      @sock = sock
      @done = false
      @stats = {}
      @procline = $0
    end

    def each
      fail 'already used this iterator' if @done

      while true
        client = UNIXSocket.new(@sock)
        r, w, e = IO.select([client], nil, [client], nil)
        break if !e.empty?

        if data = client.read(16384)
          client.close
          item = Marshal.load(data)
          $0 = "#{@procline} - #{item.respond_to?(:description) ? item.description : item}"

          start = Time.now
          yield item
          @stats[item] = Time.now - start
        else
          break
        end
      end
    rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
    ensure
      @done = true
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
