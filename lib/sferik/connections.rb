# frozen_string_literal: true

require "net/http"
require "openssl"
require "zlib"
require_relative "errors"

module Sferik
  # The connections a client makes its requests over
  #
  # A client's own open one for each request, and close it. Those of {Client#keep_alive} keep each one they open,
  # by scheme, host, and port, and make the next request there over it.
  #
  # @api private
  class Connections
    # The errors Net::HTTP raises when the server can't be reached, or its response can't be read
    NETWORK_ERRORS = [IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError, Net::ProtocolError, Zlib::Error].freeze
    private_constant :NETWORK_ERRORS

    # Initialize the connections of a client
    #
    # @api private
    # @param timeouts [Hash{Symbol => Numeric}] the seconds to wait: open_timeout, read_timeout, and write_timeout
    # @param kept [Hash{Array => Net::HTTP}, nil] where to keep the connections opened, or nil to keep none
    # @return [Connections] the connections
    def initialize(timeouts, kept = nil)
      @timeouts = timeouts
      @kept = kept
    end

    # Yield connections that are kept open, and close them afterwards
    #
    # They have the same timeouts as these.
    #
    # @api private
    # @param kept [Hash{Array => Net::HTTP}] where to keep the connections opened
    # @yield [connections] the requests to make
    # @yieldparam connections [Connections] connections that are kept open
    # @yieldreturn [Object] anything
    # @return [Object] what the block returns
    def keeping(kept = {})
      yield self.class.new(@timeouts, kept)
    ensure
      kept.each_value(&:finish)
    end

    # Send a request
    #
    # @api private
    # @param request [Net::HTTPRequest] the request, to a URL
    # @return [Net::HTTPResponse] the response
    # @raise [NetworkError] if the server can't be reached, or its response can't be read
    def request(request)
      uri = request.uri
      connection(uri) { |http| http.request(request) }
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "#{e.class}: #{e} (#{request.method} #{uri})"
    end

    private

    # Yield a connection to the host of a URL
    #
    # It's the one kept for that scheme, host, and port, opened if there's none yet, and left open. If none are
    # kept, it's a new one, closed after the block.
    #
    # @api private
    # @param uri [URI::HTTP] the URL
    # @yield [http] the request to make
    # @yieldparam http [Net::HTTP] the connection
    # @yieldreturn [Net::HTTPResponse] the response
    # @return [Net::HTTPResponse] the response
    def connection(uri, &)
      kept = @kept
      return start(uri, &) unless kept

      yield(kept[[uri.scheme, uri.hostname, uri.port]] ||= start(uri))
    end

    # Open a connection to the host of a URL
    #
    # @api private
    # @param uri [URI::HTTP] the URL
    # @yield [http] what to do with the connection, which is closed afterwards
    # @yieldparam http [Net::HTTP] the connection
    # @yieldreturn [Object] anything
    # @return [Object, Net::HTTP] what the block returns, or without one, the connection, left open
    def start(uri, &)
      hostname = uri.hostname #: String
      Net::HTTP.start(hostname, uri.port, use_ssl: uri.scheme.eql?("https"), **@timeouts, &) # steep:ignore BlockTypeMismatch
    end
  end
  private_constant :Connections
end
