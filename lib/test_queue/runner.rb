# frozen_string_literal: true

require 'set'
require 'socket'
require 'fileutils'
require 'securerandom'
require_relative 'stats'
require_relative 'test_framework'
require_relative 'transport'

module TestQueue
  class Worker
    attr_accessor :pid, :status, :output, :num, :host
    attr_accessor :start_time, :end_time
    attr_accessor :summary, :failure_output

    # Array of TestQueue::Stats::Suite recording all the suites this worker ran.
    attr_reader :suites

    def initialize(pid, num)
      @pid = pid
      @num = num
      @start_time = Time.now
      @output = ''
      @suites = []
    end

    def lines
      @output.split("\n")
    end
  end

  class Runner
    attr_accessor :concurrency, :exit_when_done
    attr_reader :stats

    def initialize(test_framework, concurrency = nil, transport = nil, relay = nil)
      @test_framework = test_framework
      @stats = Stats.new(stats_file)

      @early_failure_limit = nil
      if ENV['TEST_QUEUE_EARLY_FAILURE_LIMIT']
        begin
          @early_failure_limit = Integer(ENV['TEST_QUEUE_EARLY_FAILURE_LIMIT'])
        rescue ArgumentError
          raise ArgumentError, 'TEST_QUEUE_EARLY_FAILURE_LIMIT could not be parsed as an integer'
        end
      end

      @procline = $0

      @allowlist = if (forced = ENV['TEST_QUEUE_FORCE'])
                     forced.split(/\s*,\s*/)
                   else
                     []
                   end
      @allowlist.freeze

      all_files = @test_framework.all_suite_files.to_set
      @queue = @stats.all_suites
                     .select { |suite| all_files.include?(suite.path) }
                     .sort_by { |suite| -suite.duration }
                     .map { |suite| [suite.name, suite.path] }

      if @allowlist.any?
        @queue.select! { |suite_name, _path| @allowlist.include?(suite_name) }
        @queue.sort_by! { |suite_name, _path| @allowlist.index(suite_name) }
      end

      @awaited_suites = Set.new(@allowlist)
      @original_queue = Set.new(@queue).freeze

      @workers = {}
      @completed = []

      @concurrency = concurrency || ENV['TEST_QUEUE_WORKERS']&.to_i ||
                     if File.exist?('/proc/cpuinfo')
                       File.read('/proc/cpuinfo').split("\n").grep(/processor/).size
                     elsif RUBY_PLATFORM.include?('darwin')
                       `/usr/sbin/sysctl -n hw.activecpu`.to_i
                     else
                       2
                     end
      unless @concurrency > 0
        raise ArgumentError, "Worker count (#{@concurrency}) must be greater than 0"
      end

      @relay_connection_timeout = ENV['TEST_QUEUE_RELAY_TIMEOUT']&.to_i || 30
      @run_token = ENV['TEST_QUEUE_RELAY_TOKEN'] || SecureRandom.hex(8)
      @transport = transport || ENV['TEST_QUEUE_TRANSPORT'] || "/tmp/test_queue_#{$$}_#{object_id}.sock"
      @relay = relay || ENV['TEST_QUEUE_RELAY']
      @remote_master_message = ENV['TEST_QUEUE_REMOTE_MASTER_MESSAGE'] if ENV.key?('TEST_QUEUE_REMOTE_MASTER_MESSAGE')

      if @relay == @transport
        warn '*** Detected TEST_QUEUE_RELAY == TEST_QUEUE_TRANSPORT. Disabling relay mode.'
        @relay = nil
      elsif @relay
        @queue = []
      end

      @discovered_suites = Set.new
      @assignments = {}

      @exit_when_done = true

      @aborting = false
    end

    # Run the tests.
    #
    # If exit_when_done is true, exit! will be called before this method
    # completes. If exit_when_done is false, this method will return an Integer
    # number of failures.
    def execute
      $stdout.sync = $stderr.sync = true
      @start_time = Time.now

      execute_internal
      exitstatus = summarize_internal

      if exit_when_done
        exit! exitstatus
      else
        exitstatus
      end
    end

    def summarize_internal
      puts
      puts "==> Summary (#{@completed.size} workers in %.4fs)" % (Time.now - @start_time)
      puts

      estatus = 0
      misrun_suites = []
      unassigned_suites = []
      @failures = ''
      @completed.each do |worker|
        estatus += (worker.status.exitstatus || 1)
        @stats.record_suites(worker.suites)
        worker.suites.each do |suite|
          assignment = @assignments.delete([suite.name, suite.path])
          host = worker.host || Socket.gethostname
          if assignment.nil?
            unassigned_suites << [suite.name, suite.path]
          elsif assignment != [host, worker.pid]
            misrun_suites << [suite.name, suite.path] + assignment + [host, worker.pid]
          end
          @discovered_suites.delete([suite.name, suite.path])
        end

        summarize_worker(worker)

        @failures += worker.failure_output if worker.failure_output

        puts '    [%2d] %60s      %4d suites in %.4fs      (%s %s)' % [
          worker.num,
          worker.summary,
          worker.suites.size,
          worker.end_time - worker.start_time,
          worker.status.to_s,
          worker.host && " on #{worker.host.split('.').first}"
        ]
      end

      unless @failures.empty?
        puts
        puts '==> Failures'
        puts
        puts @failures
      end

      unless relay?
        unless @discovered_suites.empty?
          estatus += 1
          puts
          puts 'The following suites were discovered but were not run:'
          puts

          @discovered_suites.sort.each do |suite_name, path|
            puts "#{suite_name} - #{path}"
          end
        end
        unless unassigned_suites.empty?
          estatus += 1
          puts
          puts 'The following suites were not discovered but were run anyway:'
          puts
          unassigned_suites.sort.each do |suite_name, path|
            puts "#{suite_name} - #{path}"
          end
        end
        unless misrun_suites.empty?
          estatus += 1
          puts
          puts 'The following suites were run on the wrong workers:'
          puts
          misrun_suites.each do |suite_name, path, target_host, target_pid, actual_host, actual_pid|
            puts "#{suite_name} - #{path}: #{actual_host} (#{actual_pid}) - assigned to #{target_host} (#{target_pid})"
          end
        end
      end

      puts

      @stats.save

      summarize

      estatus = @completed.inject(0) { |s, worker| s + (worker.status.exitstatus || 1) }
      [estatus, 255].min
    end

    def summarize
    end

    def stats_file
      ENV['TEST_QUEUE_STATS'] || '.test_queue_stats'
    end

    def execute_internal
      start_master
      prepare(@concurrency)
      @prepared_time = Time.now
      start_relay if relay?
      discover_suites
      spawn_workers
      distribute_queue
    ensure
      stop_master

      kill_subprocesses
    end

    def start_master
      unless relay?
        @server = Transport.server(@transport, @run_token)
      end

      desc = "test-queue master (#{relay? ? "relaying to #{@relay}" : @transport})"
      puts "Starting #{desc}"
      $0 = "#{desc} - #{@procline}"
    end

    def start_relay
      return unless relay?

      response = Transport.client(@relay, @run_token).start_relay(@concurrency, @remote_master_message)
      if response != 'OK'
        warn "*** Got non-OK response from master: #{response}"
        exit! 1
      end
    end

    def stop_master
      return if relay?

      @server.stop rescue nil if @server
      @transport = @server = nil
    end

    def spawn_workers
      @concurrency.times do |i|
        num = i + 1

        pid = fork do
          @server&.close

          iterator = Iterator.new(@test_framework, relay? ? @relay : @transport, method(:around_filter), early_failure_limit: @early_failure_limit, run_token: @run_token)
          after_fork_internal(num, iterator)
          ret = run_worker(iterator) || 0
          cleanup_worker
          Kernel.exit! ret
        end

        @workers[pid] = Worker.new(pid, num)
      end
    end

    def discover_suites
      # Remote masters don't discover suites; the central master does and
      # distributes them to remote masters.
      return if relay?

      # No need to discover suites if all allowlisted suites are already
      # queued.
      return if @allowlist.any? && @awaited_suites.empty?

      @discovering_suites_pid = fork do
        terminate = false
        Signal.trap('INT') { terminate = true }

        $0 = 'test-queue suite discovery process'

        @test_framework.all_suite_files.each do |path|
          @test_framework.suites_from_file(path).each do |suite_name, _suite|
            Kernel.exit!(0) if terminate

            Transport.client(@transport, @run_token).new_suite(suite_name, path)
          end
        end

        Kernel.exit! 0
      end
    end

    def awaiting_suites?
      # We're waiting to find all the allowlisted suites so we can run them in the correct order.
      # Or we don't have any suites yet, but we're working on it.
      if @awaited_suites.any? || @queue.empty? && !!@discovering_suites_pid
        true
      else
        # It's fine to run any queued suites now.
        false
      end
    end

    def enqueue_discovered_suite(suite_name, path)
      if @allowlist.any? && !@allowlist.include?(suite_name)
        return
      end

      @discovered_suites << [suite_name, path]

      if @original_queue.include?([suite_name, path])
        # This suite was already added to the queue some other way.
        @awaited_suites.delete(suite_name)
        return
      end

      # We don't know how long new suites will take to run, so we put them at
      # the front of the queue. It's better to run a fast suite early than to
      # run a slow suite late.
      @queue.unshift [suite_name, path]

      if @awaited_suites.delete?(suite_name) && @awaited_suites.empty?
        # We've found all the allowlisted suites. Sort the queue to match the
        # allowlist.
        @queue.sort_by! { |queued_suite_name, _path| @allowlist.index(queued_suite_name) }

        kill_suite_discovery_process('INT')
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
      puts "==> Starting #{$0} (#{Process.pid} on #{Socket.gethostname}) - iterating over #{iterator.client}"
      puts

      after_fork(num)
    end

    # Run in the master before the fork. Used to create
    # concurrency copies of any databases required by the
    # test workers.
    def prepare(concurrency)
    end

    def around_filter(_suite)
      yield
    end

    # Prepare a worker for executing jobs after a fork.
    def after_fork(num)
    end

    # Entry point for internal runner implementations. The iterator will yield
    # jobs from the shared queue on the master.
    #
    # Returns an Integer number of failures.
    def run_worker(iterator)
      iterator.each do |item|
        puts "  #{item.inspect}"
      end

      0 # exit status
    end

    def cleanup_worker
    end

    def summarize_worker(worker)
      worker.summary = ''
      worker.failure_output = ''
    end

    def reap_workers(blocking = true)
      @workers.delete_if do |_, worker|
        if Process.waitpid(worker.pid, blocking ? 0 : Process::WNOHANG).nil?
          next false
        end

        worker.status = $?
        worker.end_time = Time.now

        collect_worker_data(worker)
        relay_to_master(worker) if relay?
        worker_completed(worker)

        true
      end
    end

    def collect_worker_data(worker)
      if File.exist?(file = "/tmp/test_queue_worker_#{worker.pid}_output")
        worker.output = File.binread(file)
        FileUtils.rm(file)
      end

      if File.exist?(file = "/tmp/test_queue_worker_#{worker.pid}_suites")
        worker.suites.replace(Marshal.load(File.binread(file)))
        FileUtils.rm(file)
      end
    end

    def worker_completed(worker)
      return if @aborting

      @completed << worker
      puts worker.output if ENV['TEST_QUEUE_VERBOSE'] || worker.status.exitstatus != 0
    end

    def distribute_queue
      return if relay?

      remote_workers = 0

      until !awaiting_suites? && @queue.empty? && remote_workers == 0
        queue_status(@start_time, @queue.size, @workers.size, remote_workers)

        if (status = reap_suite_discovery_process(false))
          abort('Discovering suites failed.') unless status.success?
          abort("Failed to discover #{@awaited_suites.sort.join(', ')} specified in TEST_QUEUE_FORCE") if @awaited_suites.any?
        end

        request = @server.next_request
        if request.nil?
          reap_workers(false) # check for worker deaths
        else
          # If we have a remote master from a different test run, respond with "WRONG RUN", and it will consider the test run done.
          if request.token != @run_token
            message = request.token.nil? ? 'Worker sent no token to master' : "Worker from run #{request.token} connected to master"
            warn "*** #{message} for run #{@run_token}; ignoring."
            request.wrong_run
            next
          end

          case request.cmd
          when /\APOP (\S+) (\d+)/
            hostname = $1
            pid = Integer($2)
            if awaiting_suites?
              request.wait
            elsif (obj = @queue.shift)
              request.pop(obj)
              @assignments[obj] = [hostname, pid]
            end
          when /\AREMOTE MASTER (\d+) ([\w.-]+)(?: (.+))?/
            num = $1.to_i
            remote_master = $2
            remote_master_message = $3

            request.ok
            remote_workers += num

            message = "*** #{num} workers connected from #{remote_master} after #{Time.now - @start_time}s"
            message += " #{remote_master_message}" if remote_master_message
            warn message
          when /\AWORKER (\d+)/
            worker = request.read_worker($1.to_i)
            worker_completed(worker)
            remote_workers -= 1
          when /\ANEW SUITE (.+)/
            suite_name, path = Marshal.load($1)
            enqueue_discovered_suite(suite_name, path)
          when /\AKABOOM/
            # worker reporting an abnormal number of test failures;
            # stop everything immediately and report the results.
            break
          else
            warn("Ignoring unrecognized command: \"#{cmd}\"")
          end
          request.close
        end
      end
    ensure
      stop_master
      reap_workers
    end

    def relay?
      !!@relay
    end

    def relay_to_master(worker)
      worker.host = Socket.gethostname
      data = Marshal.dump(worker)

      Transport.client(@relay, @run_token).relay_to_master(data)
    end

    def kill_subprocesses
      kill_workers
      kill_suite_discovery_process
    end

    def kill_workers
      @workers.each do |pid, _worker|
        Process.kill 'KILL', pid
      end

      reap_workers
    end

    def kill_suite_discovery_process(signal = 'KILL')
      return unless @discovering_suites_pid

      Process.kill signal, @discovering_suites_pid
      reap_suite_discovery_process
    end

    def reap_suite_discovery_process(blocking = true)
      return unless @discovering_suites_pid

      _, status = Process.waitpid2(@discovering_suites_pid, blocking ? 0 : Process::WNOHANG)
      return unless status

      @discovering_suites_pid = nil
      status
    end

    # Stop the test run immediately.
    #
    # message - String message to print to the console when exiting.
    #
    # Doesn't return.
    def abort(message)
      @aborting = true
      kill_subprocesses
      Kernel.abort("Aborting: #{message}")
    end

    # Subclasses can override to monitor the status of the queue.
    #
    # For example, you may want to record metrics about how quickly remote
    # workers connect, or abort the build if not enough connect.
    #
    # This method is called very frequently during the test run, so don't do
    # anything expensive/blocking.
    #
    # This method is not called on remote masters when using remote workers,
    # only on the central master.
    #
    # start_time          - Time when the test run began
    # queue_size          - Integer number of suites left in the queue
    # local_worker_count  - Integer number of active local workers
    # remote_worker_count - Integer number of active remote workers
    #
    # Returns nothing.
    def queue_status(start_time, queue_size, local_worker_count, remote_worker_count)
    end
  end
end
