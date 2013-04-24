require 'fileutils'
require 'socket'

module TestQueue
  class Worker
    attr_accessor :pid, :status, :output, :stats, :num
    attr_accessor :start_time, :end_time

    def initialize(pid, num)
      @pid = pid
      @num = num
      @start_time = Time.now
    end

    def lines
      @output.split("\n")
    end
  end

  class Runner
    attr_accessor :concurrency

    def initialize(queue, concurrency=nil)
      raise ArgumentError, 'array required' unless Array === queue

      @queue = queue
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
    end

    def execute
      @concurrency > 0 ?
        execute_parallel :
        execute_sequential
    ensure
      puts
      puts "==> Summary"
      puts

      @failures = ''
      @completed.each do |worker|
        summary, failures = summarize_worker(worker)
        @failures << failures if failures

        puts "    [%d] %55s      in %.4fs      (pid %d exit %d)" % [
          worker.num,
          summary,
          worker.end_time - worker.start_time,
          worker.pid,
          worker.status.exitstatus
        ]
      end

      unless @failures.empty?
        puts
        puts "==> Failures"
        puts
        puts @failures
        puts
      end

      exit! @completed.inject(0){ |s, worker| s + worker.status.exitstatus }
    end

    def execute_sequential
      exit! run_worker(@queue)
    end

    def execute_parallel
      start_master
      spawn_workers
      distribute_queue
    ensure
      stop_master

      @workers.each do |pid, worker|
        Process.kill 'KILL', pid
      end

      until @workers.empty?
        cleanup_worker
      end
    end

    def start_master
      @socket = "/tmp/test_queue_#{$$}_#{object_id}.sock"
      FileUtils.rm(@socket) if File.exists?(@socket)
      @server = UNIXServer.new(@socket)
    end

    def stop_master
      FileUtils.rm_f(@socket) if @socket
      @server.close rescue nil if @server
      @socket = @server = nil
    end

    def spawn_workers
      @concurrency.times do |i|
        pid = fork do
          @server.close
          after_fork(i)
          exit! run_worker(iterator = Iterator.new(@socket)) || 0
        end

        @workers[pid] = Worker.new(pid, i)
      end
    end

    def after_fork(num)
      srand

      output = File.open("/tmp/test_queue_worker_#{$$}_output", 'w')
      output.sync = true

      $stdout.reopen(output)
      $stderr.reopen($stdout)

      $0 = "ruby test-queue worker [#{num}]"
      puts
      puts "==> Starting #$0 (#{Process.pid})"
      puts
    end

    def run_worker(iterator)
      iterator.each do |item|
        puts "  #{item.inspect}"
      end

      return 0 # exit status
    end

    def summarize_worker(worker)
      num_tests = ''
      failures = ''

      [ num_tests, failures ]
    end

    def cleanup_worker
      if pid = Process.waitpid and worker = @workers.delete(pid)
        @completed << worker
        worker.status = $?
        worker.end_time = Time.now

        if File.exists?(file = "/tmp/test_queue_worker_#{pid}_output")
          worker.output = IO.binread(file)
          puts worker.output
          FileUtils.rm(file)
        end

        if File.exists?(file = "/tmp/test_queue_worker_#{pid}_stats")
          worker.stats = Marshal.load(IO.binread(file))
          FileUtils.rm(file)
        end
      end
    end

    def distribute_queue
      until @queue.empty?
        IO.select([@server], nil, nil, nil)

        sock = @server.accept
        sock.write(Marshal.dump(@queue.shift))
        sock.close
      end
    ensure
      stop_master

      until @workers.empty?
        cleanup_worker
      end
    end
  end
end
