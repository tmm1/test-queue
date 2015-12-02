module TestQueue
  class Iterator
    attr_reader :stats, :sock

    def initialize(sock, suites, filter=nil)
      @done = false
      @stats = {}
      @procline = $0
      @sock = sock
      @suites = suites
      @filter = filter
      if @sock =~ /^(.+):(\d+)$/
        @tcp_address = $1
        @tcp_port = $2.to_i
      end
    end

    def query(payload)
      client = connect_to_master(payload)
      return if client.nil?
      _r, _w, e = IO.select([client], nil, [client], nil)
      return if !e.empty?

      if data = client.read(65536)
        client.close
        item = Marshal.load(data)
        return if item.nil? || item.empty?
        item
      end
    end

    def each
      fail "already used this iterator. previous caller: #@done" if @done

      while true
        if item = query('POP')
          suite = @suites[item]

          $0 = "#{@procline} - #{suite.respond_to?(:description) ? suite.description : suite}"
          start = Time.now
          if @filter
            @filter.call(suite){ yield suite }
          else
            yield suite
          end
          @stats[suite.to_s] = Time.now - start
        else
          break
        end
      end
    rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
    ensure
      @done = caller.first
      File.open("/tmp/test_queue_worker_#{$$}_stats", "wb") do |f|
        f.write Marshal.dump(@stats)
      end
    end

    def connect_to_master(cmd)
      sock =
        if @tcp_address
          TCPSocket.new(@tcp_address, @tcp_port)
        else
          UNIXSocket.new(@sock)
        end
      sock.puts(cmd)
      sock
    rescue Errno::EPIPE
      nil
    end

    include Enumerable

    def empty?
      false
    end
  end
end
