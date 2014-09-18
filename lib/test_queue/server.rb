module TestQueue
  class Server
    attr_reader :relay, :socket_address, :client_connection_timeout, :client, :run_token

    alias_method :relay?, :relay

    def initialize(
      socket_address:,
      client_connection_timeout: nil,
      relay: nil,
      relay_address: nil,
      run_token: nil
    )
      @socket_address = socket_address || "/tmp/test_queue_#{$$}_#{object_id}.sock"
      @client_connection_timeout = client_connection_timeout || 30
      @relay = relay || false
      @run_token = run_token || SecureRandom.hex(8)

      if relay_address
        if relay_address == @socket_address
          STDERR.puts "*** Detected TEST_QUEUE_RELAY == TEST_QUEUE_SOCKET. Disabling relay mode."
          @relay = false
        else
          @socket_address = relay_address
          @relay = true
        end
      end
    end

    def description
      desc = "test-queue master "
      if relay?
        desc << "(relaying to #@relay)"
      else
        desc << "(#@server)"
      end
      desc
    end

    def start
      if @socket_address =~ /^(?:(.+):)?(\d+)$/
        address = $1 || '0.0.0.0'
        port = $2.to_i
        if relay?
          @relay_client = TCPRelayClient.new(address, port, client_connection_timeout)
        else
          @server = TCPServer.new(address, port)
        end
        @client = TCPClient.new(address, port, client_connection_timeout)
      else
        FileUtils.rm(@socket_address) if File.exists?(@socket_address)
        @server = UNIXServer.new(@socket_address)
        @client = UNIXClient.new(@socket_address)
      end
      true
    end

    def start_relay(concurrency, slave_message)
      if relay?
        @relay_client.start(run_token, concurrency, slave_message)
      end
    end

    def reap_worker(worker)
      if relay?
        @relay_client.reap_worker(worker)
      end
    end

    def waiting?
      IO.select([@server], nil, nil, 0.1).nil?
    end

    def accept
      @server.accept
    end

    def close
      @server.close if @server
    end

    def stop
      return if relay?

      FileUtils.rm_f(@socket_address) if @socket_address && @server.is_a?(UNIXServer)
      close rescue nil if @server
      @socket_address = @server = nil
    end
  end

  class Client
    def pop
      client = connect
      client.puts("POP")
      _r, _w, e = IO.select([client], nil, [client], nil)
      return if !e.empty?
      if data = client.read(65536)
        client.close
        Marshal.load(data)
      end
    rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
    end

    private

    def connect
      open_socket
    rescue Errno::EPIPE
      nil
    end
  end

  class TCPClient < Client
    attr_reader :address, :port, :timeout

    def initialize(address, port, timeout)
      @address = address
      @port = port
      @timeout = timeout
    end

    def socket
      "#{address}:#{port}"
    end

    private

    def open_socket
      TCPSocket.new(address, port)
    end
  end

  class TCPRelayClient < TCPClient
    def start(run_token, concurrency, slave_message)
      sock = connect
      message = [
        "CONNECT_SLAVE",
        concurrency,
        Socket.gethostname,
        run_token,
        slave_message
      ].join(" ")

      sock.puts(message)
      response = sock.gets.strip
      unless response == "OK"
        STDERR.puts "*** Got non-OK response from master: #{response}"
        sock.close
        exit! 1
      end
      sock.close
    rescue Errno::ECONNREFUSED
      STDERR.puts "*** Unable to connect to relay #@relay. Aborting.."
      exit! 1
    end

    def reap_worker(worker)
      worker.host = Socket.gethostname
      data = Marshal.dump(worker)

      puts "finishing worker"
      sock = connect
      sock.puts("WORKER_FINISHED #{data.bytesize}")
      sock.write(data)
    ensure
      sock.close if sock
    end

    def connect
      sock = nil
      start_time = Time.now
      puts "Attempting to connect for #{timeout}s..."
      while sock.nil?
        begin
          sock = open_socket
        rescue Errno::ECONNREFUSED => e
          raise e if Time.now - start_time > timeout
          puts "Master at #{socket} not yet available, sleeping..."
          sleep 0.5
        end
      end
      sock
    end
  end

  class UNIXClient < Client
    def initialize(path)
      @path = path
    end

    private

    def open_socket
      UNIXSocket.new(@path)
    end
  end
end

