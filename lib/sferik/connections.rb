# frozen_string_literal: true

require "net/http"
require "openssl"
require "zlib"
require_relative "errors"

module Sferik
  # The connections a client makes its requests over
  #
  # Each one opened is kept, and the next request to the same scheme, host, and port is made over it, which saves
  # connecting again: with https, most of the time a request takes. A client's own are kept by the thread that makes
  # the request (or the fiber, which is as far as Thread.current goes), since a connection is for one at a time, and
  # by the process, since one that a fork inherits is its parent's. They're never closed here: Net::HTTP opens one
  # again that has sat unused for more than half a minute, or that the server has closed by then, and what a thread
  # leaves behind is closed when it's collected, unless {Client#close} closes them first. Those of
  # {Client#keep_alive} are kept for its block, and closed after.
  #
  # @api private
  class Connections
    # The errors Net::HTTP raises when the server can't be reached, or its response can't be read
    NETWORK_ERRORS = [IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError, Net::ProtocolError, Zlib::Error].freeze
    private_constant :NETWORK_ERRORS

    # The seconds a connection may sit unused, and still be the one the next request is made over
    #
    # Net::HTTP's own two would open one again for anything that asks every few seconds, as a {Client#cached} client
    # asking who's reading does, every five. Cloudflare leaves one open for minutes, and Net::HTTP looks whether the
    # server has closed one before it uses it, whatever this says.
    KEEP_ALIVE = 30
    private_constant :KEEP_ALIVE

    # Where a thread keeps the connections it has opened
    OPENED = :sferik_connections
    private_constant :OPENED

    # Initialize the connections of a client
    #
    # @api private
    # @param timeouts [Hash{Symbol => Numeric}] the seconds to wait: open_timeout, read_timeout, and write_timeout
    # @param kept [Hash{Array => Net::HTTP}, nil] where to keep the connections opened, or nil for the thread to
    # @return [Connections] the connections
    def initialize(timeouts, kept = nil)
      @timeouts = timeouts
      @kept = kept
    end

    # Yield connections of their own, and close them afterwards
    #
    # They have the same timeouts as these.
    #
    # @api private
    # @param kept [Hash{Array => Net::HTTP}] where to keep the connections opened
    # @yield [connections] the requests to make
    # @yieldparam connections [Connections] connections that are closed after the block
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
    # @raise [Unanswered] if the server was connected to, and its response didn't come, or can't be read
    # @raise [NetworkError] if the server can't be connected to
    def request(request)
      http = connection(request.uri)
      http.request(request)
    rescue *NETWORK_ERRORS => e
      raise (http ? Unanswered : NetworkError), "#{e.class}: #{e} (#{request.method} #{request.uri})"
    end

    # What a block makes of a response, made each time
    #
    # Only a {Cache} keeps what's made.
    #
    # @api private
    # @param _uri [URI::HTTP] the URL that was asked for
    # @param _accept [String] the media type it was asked for as
    # @param _response [Net::HTTPResponse] the response that came
    # @yield what to make of the response
    # @yieldreturn [Object] what's made of it
    # @return [Object] what the block returned
    def made(_uri, _accept, _response)
      yield
    end

    # Close the connections that are kept, and keep none of them
    #
    # One that another process opened, which a fork inherits, is only let go of: closing it here would close it for
    # the process whose it is.
    #
    # @api private
    # @return [nil]
    def close
      kept.each { |key, http| http.finish if key.first.eql?(Process.pid) }
      kept.clear
      nil
    end

    private

    # The connection to the host of a URL
    #
    # It's the one kept for that scheme, host, and port, by this process, with these timeouts, opened if there's none
    # yet, and left open.
    #
    # @api private
    # @param uri [URI::HTTP] the URL
    # @return [Net::HTTP] the connection
    def connection(uri)
      kept[[Process.pid, uri.scheme, uri.hostname, uri.port, @timeouts]] ||= start(uri)
    end

    # Where the connections opened are kept
    #
    # @api private
    # @return [Hash{Array => Net::HTTP}] where these were given to keep theirs, or else where the thread keeps its own
    def kept
      given = @kept
      return given if given

      Thread.current[OPENED] ||= {}
    end

    # Open a connection to the host of a URL
    #
    # @api private
    # @param uri [URI::HTTP] the URL
    # @return [Net::HTTP] the connection, left open
    def start(uri)
      hostname = uri.hostname #: String
      Net::HTTP.start(hostname, uri.port, use_ssl: uri.scheme.eql?("https"), keep_alive_timeout: KEEP_ALIVE, **@timeouts)
    end
  end
  private_constant :Connections
end
