# frozen_string_literal: true

require 'uri'
require_relative 'transport/socket_client'
require_relative 'transport/socket_server'

module TestQueue
  module Transport
    def self.client(transport, token)
      if http?(transport)
        HTTPClient.new(transport, token)
      else
        SocketClient.new(transport, token)
      end
    end

    def self.server(transport, token)
      if http?(transport)
        HTTPServer.new(transport, token)
      else
        SocketServer.new(transport, token)
      end
    end

    def self.http?(transport)
      !transport.nil? && ['http', 'https'].include?(URI(transport).scheme)
    end
  end
end
