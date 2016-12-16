module TestQueue
  class Iterator
    attr_reader :sock

    def initialize(test_framework, sock, filter=nil, run_token:, early_failure_limit: nil)
      @test_framework = test_framework
      @done = false
      @suite_stats = []
      @sock = sock
      @filter = filter
      if @sock =~ /^(.+):(\d+)$/
        @tcp_address = $1
        @tcp_port = $2.to_i
      end
      @failures = 0
      @early_failure_limit = early_failure_limit
      @run_token = run_token
    end

    def each
      fail "already used this iterator. previous caller: #@done" if @done

      procline = $0

      while true
        # If we've hit too many failures in one worker, assume the entire
        # test suite is broken, and notify master so the run
        # can be immediately halted.
        if @early_failure_limit && @failures >= @early_failure_limit
          connect_to_master("KABOOM")
          break
        else
          client = connect_to_master("POP #{Socket.gethostname} #{Process.pid}")
        end
        break if client.nil?
        _r, _w, e = IO.select([client], nil, [client], nil)
        break if !e.empty?

        if data = client.read(65536)
          client.close
          item = Marshal.load(data)
          break if item.nil? || item.empty?
          if item == "WAIT"
            $0 = "#{procline} - Waiting for work"
            sleep 0.1
            next
          end
          suite_name, path = item
          suite = load_suite(suite_name, path)

          # Maybe we were told to load a suite that doesn't exist anymore.
          next unless suite

          $0 = "#{procline} - #{suite.respond_to?(:description) ? suite.description : suite}"
          start = Time.now
          if @filter
            @filter.call(suite){ yield suite }
          else
            yield suite
          end
          @suite_stats << TestQueue::Stats::Suite.new(suite_name, path, Time.now - start, Time.now)
          @failures += suite.failure_count if suite.respond_to? :failure_count
        else
          break
        end
      end
    rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
    ensure
      $0 = procline
      @done = caller.first
      File.open("/tmp/test_queue_worker_#{$$}_suites", "wb") do |f|
        Marshal.dump(@suite_stats, f)
      end
    end

    def connect_to_master(cmd)
      sock =
        if @tcp_address
          TCPSocket.new(@tcp_address, @tcp_port)
        else
          UNIXSocket.new(@sock)
        end
      sock.puts("TOKEN=#{@run_token}")
      sock.puts(cmd)
      sock
    rescue Errno::EPIPE
      nil
    end

    include Enumerable

    def empty?
      false
    end

    def load_suite(suite_name, path)
      @loaded_suites ||= {}
      suite = @loaded_suites[suite_name]
      return suite if suite

      @test_framework.suites_from_file(path).each do |name, suite|
        @loaded_suites[name] = suite
      end
      @loaded_suites[suite_name]
    end
  end
end
