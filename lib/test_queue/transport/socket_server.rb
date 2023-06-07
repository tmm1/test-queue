# frozen_string_literal: true

require 'socket'

module TestQueue
  module Transport
    TOKEN_REGEX = /\ATOKEN=(\w+)/

    class SocketServer
      class Request
        attr_reader :token, :cmd

        def initialize(token, cmd, sock)
          @token = token
          @cmd = cmd
          @sock = sock
        end

        def wrong_run
          @sock.write("WRONG RUN\n")
        end

        def wait
          @sock.write(Marshal.dump('WAIT'))
        end

        def pop(obj)
          data = Marshal.dump(obj)
          @sock.write(data)
        end

        def ok
          @sock.write("OK\n")
        end

        def read_worker(size)
          data = @sock.read(size)
          Marshal.load(data)
        end

        def close
          @sock.close
        end
      end

      def initialize(transport, token)
        @socket = transport
        @token = token
        if @socket =~ /\Atcp:\/\/(.+):(\d+)\z/
          address = $1
          port = $2.to_i
          @server = TCPServer.new(address, port)
        else
          FileUtils.rm_f(@socket)
          @server = UNIXServer.new(@socket)
        end
      end

      def stop
        FileUtils.rm_f(@socket) if @socket && @server.is_a?(UNIXServer)
        @server.close rescue nil if @server
        @socket = @server = nil
      end

      def close
        @server&.close
      end

      def next_request
        return nil if @server.wait_readable(0.1).nil?

        sock = @server.accept
        token = sock.gets.strip
        token = token[TOKEN_REGEX, 1]
        cmd = sock.gets.strip
        Request.new(token, cmd, sock)
      end
    end
  end
end
