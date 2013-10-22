module TestQueue
  class Iterator
    attr_reader :stats

    def initialize(sock)
      @done = false
      @stats = {}
      @procline = $0
      @sock = sock
      if @sock =~ /^(.+):(\d+)$/
        @tcp_address = $1
        @tcp_port = $2.to_i
      end
    end

    def each
      fail 'already used this iterator' if @done

      while true
        client = connect_to_master
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

    def connect_to_master
      if @tcp_address
        TCPSocket.new(@tcp_address, @tcp_port)
      else
        UNIXSocket.new(@sock)
      end
    end

    include Enumerable

    def empty?
      false
    end
  end
end
