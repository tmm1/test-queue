require 'socket'
require 'fileutils'
require 'securerandom'

module TestQueue
  class Worker
    attr_accessor :pid, :status, :output, :stats, :num, :host
    attr_accessor :start_time, :end_time
    attr_accessor :summary, :failure_output

    def initialize(pid, num)
      @pid = pid
      @num = num
      @start_time = Time.now
      @output = ''
      @stats = {}
    end

    def lines
      @output.split("\n")
    end
  end

  class Runner
    attr_accessor :concurrency

    def initialize(queue, concurrency=nil, socket=nil, relay=nil)
      raise ArgumentError, 'array required' unless Array === queue

      if forced = ENV['TEST_QUEUE_FORCE']
        forced = forced.split(/\s*,\s*/)
        whitelist = Set.new(forced)
        queue = queue.select{ |s| whitelist.include?(s.to_s) }
        queue.sort_by!{ |s| forced.index(s.to_s) }
      end

      @procline = $0
      @suites = queue.inject(Hash.new) do |hash, suite|
        key = suite.respond_to?(:id) ? suite.id : suite.to_s
        hash.update key => suite
      end
      @queue = @suites.keys

      @workers = {}
      @completed = []

      @concurrency =
        concurrency ||
        (ENV['TEST_QUEUE_WORKERS'] && ENV['TEST_QUEUE_WORKERS'].to_i) ||
        if File.exists?('/proc/cpuinfo')
          File.read('/proc/cpuinfo').split("\n").grep(/processor/).size
        elsif RUBY_PLATFORM =~ /darwin/
          `/usr/sbin/sysctl -n hw.activecpu`.to_i
        else
          2
        end

      @slave_connection_timeout =
        (ENV['TEST_QUEUE_RELAY_TIMEOUT'] && ENV['TEST_QUEUE_RELAY_TIMEOUT'].to_i) ||
        30

      @run_token = ENV['TEST_QUEUE_RELAY_TOKEN'] || SecureRandom.hex(8)

      @socket =
        socket ||
        ENV['TEST_QUEUE_SOCKET'] ||
        "/tmp/test_queue_#{$$}_#{object_id}.sock"

      @relay =
        relay ||
        ENV['TEST_QUEUE_RELAY']

      @slave_message = ENV["TEST_QUEUE_SLAVE_MESSAGE"] if ENV.has_key?("TEST_QUEUE_SLAVE_MESSAGE")

      if @relay == @socket
        STDERR.puts "*** Detected TEST_QUEUE_RELAY == TEST_QUEUE_SOCKET. Disabling relay mode."
        @relay = nil
      elsif @relay
        @queue = []
      end
    end

    def stats
      @stats ||=
        if File.exists?(file = stats_file)
          Marshal.load(IO.binread(file)) || {}
        else
          {}
        end
    end

    def execute
      $stdout.sync = $stderr.sync = true
      @start_time = Time.now

      @concurrency > 0 ?
        execute_parallel :
        execute_sequential
    ensure
      summarize_internal unless $!
    end

    def summarize_internal
      puts
      puts "==> Summary (#{@completed.size} workers in %.4fs)" % (Time.now-@start_time)
      puts

      @failures = ''
      @completed.each do |worker|
        summarize_worker(worker)
        @failures << worker.failure_output if worker.failure_output

        puts "    [%2d] %60s      %4d suites in %.4fs      (pid %d exit %d%s)" % [
          worker.num,
          worker.summary,
          worker.stats.size,
          worker.end_time - worker.start_time,
          worker.pid,
          worker.status.exitstatus,
          worker.host && " on #{worker.host.split('.').first}"
        ]
      end

      unless @failures.empty?
        puts
        puts "==> Failures"
        puts
        puts @failures
      end

      puts

      if @stats
        File.open(stats_file, 'wb') do |f|
          f.write Marshal.dump(stats)
        end
      end

      summarize

      estatus = @completed.inject(0){ |s, worker| s + worker.status.exitstatus }
      estatus = 255 if estatus > 255
      exit!(estatus)
    end

    def summarize
    end

    def stats_file
      ENV['TEST_QUEUE_STATS'] ||
      '.test_queue_stats'
    end

    def execute_sequential
      exit! run_worker(@queue)
    end

    def execute_parallel
      start_master
      prepare(@concurrency)
      @prepared_time = Time.now
      start_relay if relay?
      spawn_workers
      distribute_queue
    ensure
      stop_master

      @workers.each do |pid, worker|
        Process.kill 'KILL', pid
      end

      until @workers.empty?
        reap_worker
      end
    end

    def start_master
      if !relay?
        if @socket =~ /^(?:(.+):)?(\d+)$/
          address = $1 || '0.0.0.0'
          port = $2.to_i
          @socket = "#$1:#$2"
          @server = TCPServer.new(address, port)
        else
          FileUtils.rm(@socket) if File.exists?(@socket)
          @server = UNIXServer.new(@socket)
        end
      end

      desc = "test-queue master (#{relay?? "relaying to #{@relay}" : @socket})"
      puts "Starting #{desc}"
      $0 = "#{desc} - #{@procline}"
    end

    def start_relay
      return unless relay?

      sock = connect_to_relay
      message = @slave_message ? " #{@slave_message}" : ""
      message.gsub!(/(\r|\n)/, "") # Our "protocol" is newline-separated
      sock.puts("SLAVE #{@concurrency} #{Socket.gethostname} #{@run_token}#{message}")
      response = sock.gets.strip
      unless response == "OK"
        STDERR.puts "*** Got non-OK response from master: #{response}"
        sock.close
        exit! 1
      end
      sock.close
    rescue Errno::ECONNREFUSED
      STDERR.puts "*** Unable to connect to relay #{@relay}. Aborting.."
      exit! 1
    end

    def stop_master
      return if relay?

      FileUtils.rm_f(@socket) if @socket && @server.is_a?(UNIXServer)
      @server.close rescue nil if @server
      @socket = @server = nil
    end

    def spawn_workers
      @concurrency.times do |i|
        num = i+1

        pid = fork do
          @server.close if @server

          iterator = Iterator.new(relay?? @relay : @socket, @suites, method(:around_filter))
          after_fork_internal(num, iterator)
          ret = run_worker(iterator) || 0
          cleanup_worker
          Kernel.exit! ret
        end

        @workers[pid] = Worker.new(pid, num)
      end
    end

    def after_fork_internal(num, iterator)
      srand

      output = File.open("/tmp/test_queue_worker_#{$$}_output", 'w')

      $stdout.reopen(output)
      $stderr.reopen($stdout)
      $stdout.sync = $stderr.sync = true

      $0 = "test-queue worker [#{num}]"
      puts
      puts "==> Starting #$0 (#{Process.pid} on #{Socket.gethostname}) - iterating over #{iterator.sock}"
      puts

      after_fork(num)
    end

    # Run in the master before the fork. Used to create
    # concurrency copies of any databases required by the
    # test workers.
    def prepare(concurrency)
    end

    def around_filter(suite)
      yield
    end

    # Prepare a worker for executing jobs after a fork.
    def after_fork(num)
    end

    # Entry point for internal runner implementations. The iterator will yield
    # jobs from the shared queue on the master.
    #
    # Returns nothing. exits 0 on success.
    # exits N on error, where N is the number of failures.
    def run_worker(iterator)
      iterator.each do |item|
        puts "  #{item.inspect}"
      end

      return 0 # exit status
    end

    def cleanup_worker
    end

    def summarize_worker(worker)
      worker.summary = ''
      worker.failure_output = ''
    end

    def reap_worker(blocking=true)
      if pid = Process.waitpid(-1, blocking ? 0 : Process::WNOHANG) and worker = @workers.delete(pid)
        worker.status = $?
        worker.end_time = Time.now

        if File.exists?(file = "/tmp/test_queue_worker_#{pid}_output")
          worker.output = IO.binread(file)
          FileUtils.rm(file)
        end

        if File.exists?(file = "/tmp/test_queue_worker_#{pid}_stats")
          worker.stats = Marshal.load(IO.binread(file))
          FileUtils.rm(file)
        end

        relay_to_master(worker) if relay?
        worker_completed(worker)
      end
    end

    def worker_completed(worker)
      @completed << worker
      puts worker.output if ENV['TEST_QUEUE_VERBOSE'] || worker.status.exitstatus != 0
    end

    def distribute_queue
      return if relay?
      remote_workers = 0

      until @queue.empty? && remote_workers == 0
        if IO.select([@server], nil, nil, 0.1).nil?
          reap_worker(false) if @workers.any? # check for worker deaths
        else
          sock = @server.accept
          cmd = sock.gets.strip
          case cmd
          when /^POP/
            # If we have a slave from a different test run, don't respond, and it will consider the test run done.
            if obj = @queue.shift
              data = Marshal.dump(obj.to_s)
              sock.write(data)
            end
          when /^SLAVE (\d+) ([\w\.-]+) (\w+)(?: (.+))?/
            num = $1.to_i
            slave = $2
            run_token = $3
            slave_message = $4
            if run_token == @run_token
              # If we have a slave from a different test run, don't respond, and it will consider the test run done.
              sock.write("OK\n")
              remote_workers += num
            else
              STDERR.puts "*** Worker from run #{run_token} connected to master for run #{@run_token}; ignoring."
              sock.write("WRONG RUN\n")
            end
            message = "*** #{num} workers connected from #{slave} after #{Time.now-@start_time}s"
            message << " " + slave_message if slave_message
            STDERR.puts message
          when /^WORKER (\d+)/
            data = sock.read($1.to_i)
            worker = Marshal.load(data)
            worker_completed(worker)
            remote_workers -= 1
          end
          sock.close
        end
      end
    ensure
      stop_master

      until @workers.empty?
        reap_worker
      end
    end

    def relay?
      !!@relay
    end

    def connect_to_relay
      sock = nil
      start = Time.now
      puts "Attempting to connect for #{@slave_connection_timeout}s..."
      while sock.nil?
        begin
          sock = TCPSocket.new(*@relay.split(':'))
        rescue Errno::ECONNREFUSED => e
          raise e if Time.now - start > @slave_connection_timeout
          puts "Master not yet available, sleeping..."
          sleep 0.5
        end
      end
      sock
    end

    def relay_to_master(worker)
      worker.host = Socket.gethostname
      data = Marshal.dump(worker)

      sock = connect_to_relay
      sock.puts("WORKER #{data.bytesize}")
      sock.write(data)
    ensure
      sock.close if sock
    end
  end
end
