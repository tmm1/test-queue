module TestQueue
  class Command
    def initialize(sock)
      @sock = sock
    end

    def write(data)
      @sock.write(data)
    end

    def read(bytes)
      @sock.read(bytes)
    end

    def close
      @sock.close
    end

    def self.command
      word = name.split("::").last
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.upcase!
      word
    end

    class Pop < Command
      def send_item(item)
        data = Marshal.dump(item.to_s)
        write(data)
        close
      end
    end

    class ConnectSlave < Command
      attr_reader :num, :slave, :slave_token, :slave_message

      def initialize(sock, num:, slave:, slave_token:, slave_message: )
        super(sock)
        @num = num
        @slave = slave
        @slave_token = slave_token
        @slave_message = slave_message
      end

      def verify_token(run_token)
        if @slave_token == run_token
          write("OK\n")
          close
          return true
        else
          STDERR.puts "*** Worker from run #{slave_token} connected to master for run #{@slave_token}; ignoring."
          write("WRONG RUN\n")
          close
          return false
        end
      end

      def message(start_time)
        text = "*** #{num} workers connected from #{slave} after #{Time.now-start_time}s"
        text << " " + slave_message if slave_message
        text
      end
    end

    class WorkerFinished < Command
      def worker
        data = @sock.read($1.to_i)
        worker = Marshal.load(data)
        close
        worker
      end
    end
  end
end
