module TestQueue
  class Iterator
    attr_reader :stats

    def initialize(sock)
      @sock = sock
      @done = false
      @stats = {}
    end

    def each
      fail 'already used this iterator' if @done

      while true
        client = UNIXSocket.new(@sock)
        r, w, e = IO.select([client], nil, [client], nil)
        break if !e.empty?

        if data = client.read(16384)
          item = Marshal.load(data)
          client.close
          yield item
        else
          break
        end
      end
    rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
    ensure
      @done = true
    end

    include Enumerable

    def empty?
      false
    end
  end
end
