require 'fileutils'
require 'socket'

module TestQueue
  class Worker
    attr_accessor :pid, :status, :output, :stats

    def initialize(pid)
      @pid = pid
    end
  end

  class Runner
    attr_accessor :concurrency

    def initialize(queue, concurrency=nil)
      raise ArgumentError, 'array required' unless Array === queue

      @queue = queue
      @concurrency = concurrency ||
        if File.exists?('/proc/cpuinfo')
          File.read('/proc/cpuinfo').split("\n").grep(/processor/).size
        else
          2
        end
      @workers = {}
      @completed = []
    end

    def execute
      @concurrency > 0 &&
        execute_parallel ||
        execute_sequential
    end

    def execute_sequential
    end

    def execute_parallel
      start_master
      spawn_workers
      distribute_queue
      exit! @completed.inject(0){ |s, worker| s + worker.status.exitstatus }
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
          exit! run_worker(iterator = Iterator.new(@socket))
        end

        @workers[pid] = Worker.new(pid)
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
      iterator.each do
      end

      0
    end

    def cleanup_worker
      if pid = Process.waitpid and worker = @workers.delete(pid)
        @completed << worker
        worker.status = $?

        if File.exists?(file = "/tmp/test_queue_worker_#{pid}_output")
          worker.output = IO.binread(file)
          puts worker.output
          FileUtils.rm(file)
        end

        if File.exists?(file = "/tmp/test_queue_worker_#{pid}_stats")
          workers.stats = Marshal.load(IO.binread(file))
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
