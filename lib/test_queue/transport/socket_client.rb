# frozen_string_literal: true

require 'socket'

module TestQueue
  module Transport
    class SocketClient
      attr_reader :sock

      def initialize(sock, token, timeout: nil)
        @sock = sock
        @token = token
        @timeout = timeout
        if @sock =~ /\Atcp:\/\/(.+):(\d+)\z/
          @tcp_address = $1
          @tcp_port = $2.to_i
        end
      end

      def to_s
        @sock
      end

      def pop
        client = connect_to_master("POP #{Socket.gethostname} #{Process.pid}")
        return if client.nil?

        # This false positive will be resolved by https://github.com/rubocop/rubocop/pull/11830.
        _r, _w, e = IO.select([client], nil, [client], nil)
        return unless e.empty?

        data = client.read(65536)
        return unless data

        client.close
        Marshal.load(data)
      rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
        nil
      end

      def kaboom
        connect_to_master('KABOOM')
      rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
        nil
      end

      def new_suite(suite_name, path)
        connect_to_master("NEW SUITE #{Marshal.dump([suite_name, path])}")
      end

      def start_relay(concurrency, message)
        sock = connect_to_relay
        message = message ? " #{message}" : ''
        message = message.gsub(/(\r|\n)/, '') # Our "protocol" is newline-separated
        sock.puts("TOKEN=#{@token}")
        sock.puts("REMOTE MASTER #{concurrency} #{Socket.gethostname} #{message}")
        response = sock.gets.strip
        sock.close
        response
      rescue Errno::ECONNREFUSED
        "Unable to connect to relay #{@sock}. Aborting..."
      end

      def relay_to_master(data)
        sock = connect_to_relay
        sock.puts("TOKEN=#{@token}")
        sock.puts("WORKER #{data.bytesize}")
        sock.write(data)
      ensure
        sock&.close
      end

      private

      def connect_to_master(cmd)
        sock =
          if @tcp_address
            TCPSocket.new(@tcp_address, @tcp_port)
          else
            UNIXSocket.new(@sock)
          end
        sock.puts("TOKEN=#{@token}")
        sock.puts(cmd)
        sock
      rescue Errno::EPIPE
        nil
      end

      def connect_to_relay
        sock = nil
        start = Time.now
        puts "Attempting to connect for #{@timeout}s..."
        while sock.nil?
          begin
            sock = TCPSocket.new(@tcp_address, @tcp_port)
          rescue Errno::ECONNREFUSED => e
            raise e if Time.now - start > @timeout

            puts 'Master not yet available, sleeping...'
            sleep 0.5
          end
        end
        sock
      end
    end
  end
end
