# frozen_string_literal: true

require "net/http"

module Sferik
  # Keeps the responses to a client's GET requests, and asks again only for what may have changed
  #
  # It stands where the client's {Connections} do, and makes its requests over them. A response says how long it's
  # good for (Cache-Control: max-age), and for that long the same URL asked for as the same media type is answered
  # with it, and no request is made. After that, the request says which version is kept (If-None-Match, with the
  # response's ETag), and the server answers 304 Not Modified, without a body, if that's still the one. A response
  # that says not to keep it (no-store) isn't kept, and one that says to check each time (no-cache) is checked each
  # time. Only a 200 is kept.
  #
  # A response that has already been kept somewhere on its way, as one from Cloudflare's cache has, says for how long
  # (Age), and is good for that much less. And a cache that's told to (stale) answers with a response that's no longer
  # good, when the server can't be asked whether it has changed.
  #
  # @api private
  class Cache
    # A response that's kept, with its ETag, if it has one, and when on the clock it's good until
    #
    # @!attribute [r] response
    #   The response
    #   @api private
    #   @return [Net::HTTPResponse] the response
    # @!attribute [r] etag
    #   The response's ETag
    #   @api private
    #   @return [String, nil] the ETag, or nil if the response has none
    # @!attribute [r] expires
    #   When the response is good until
    #   @api private
    #   @return [Numeric] the time on the cache's clock, in seconds
    Entry = Data.define(:response, :etag, :expires)
    private_constant :Entry

    # The time, in seconds, on a clock that only goes forward
    CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    private_constant :CLOCK

    # The seconds a Cache-Control says a response is good for
    MAX_AGE = /\bmax-age=(\d+)/i
    private_constant :MAX_AGE

    # A Cache-Control that says to check a response each time it's used
    NO_CACHE = /\bno-cache\b/i
    private_constant :NO_CACHE

    # A Cache-Control that says not to keep a response
    NO_STORE = /\bno-store\b/i
    private_constant :NO_STORE

    # Initialize a cache
    #
    # @api private
    # @param connections [Connections, Cache] what to make requests over
    # @param clock [#call] what tells the time, in seconds
    # @param entries [Hash{Array => Entry}] the responses kept, by URL and media type
    # @param lock [Mutex] what's held to read or change them
    # @param stale [Boolean] whether to answer with a response that's no longer good, when the server can't be reached
    # @return [Cache] the cache
    def initialize(connections, clock = CLOCK, entries = {}, lock = Mutex.new, stale: false)
      @connections = connections
      @clock = clock
      @entries = entries
      @lock = lock
      @stale = stale
    end

    # Yield a cache of the same responses over connections that are kept open
    #
    # @api private
    # @yield [cache] the requests to make
    # @yieldparam cache [Cache] a cache whose connections are kept open
    # @yieldreturn [Object] anything
    # @return [Object] what the block returns
    def keeping
      @connections.keeping { |kept| yield self.class.new(kept, @clock, @entries, @lock, stale: @stale) }
    end

    # Close the connections requests are made over, and keep the responses
    #
    # @api private
    # @return [nil]
    def close
      @connections.close
    end

    # Send a request, unless it's a GET whose response is kept and still good
    #
    # @api private
    # @param request [Net::HTTPRequest] the request, to a URL
    # @return [Net::HTTPResponse] the response, which may be one that was kept
    # @raise [NetworkError] if the server can't be reached, or its response can't be read, and there's no response
    #   kept to answer with instead, or the cache isn't to
    def request(request)
      return @connections.request(request) unless request.instance_of?(Net::HTTP::Get)

      key = [request.uri, request.fetch("accept")] #: key
      entry = @lock.synchronize { @entries[key] }
      (entry && @clock.call < entry.expires) ? entry.response : renew(key, entry, request)
    end

    private

    # Send a GET request, or answer with what's kept if the server can't be reached
    #
    # What comes back is kept. What's kept and no longer good is the answer only for a cache that's told to (stale).
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param entry [Entry, nil] the response kept, which is no longer good, if there is one
    # @param request [Net::HTTP::Get] the request
    # @return [Net::HTTPResponse] the response: the one kept, if the server says it hasn't changed, or can't be reached
    #   and the cache answers with what's no longer good
    # @raise [NetworkError] if the server can't be reached, or its response can't be read, and there's no response
    #   kept to answer with instead, or the cache isn't to
    def renew(key, entry, request)
      ask(key, entry, request)
    rescue NetworkError
      raise unless entry && @stale

      entry.response
    end

    # Send a GET request, and keep what comes back
    #
    # The request says which version of its response is kept, so that the server sends a body only for another.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param entry [Entry, nil] the response kept, which is no longer good, if there is one
    # @param request [Net::HTTP::Get] the request
    # @return [Net::HTTPResponse] the response: the one kept, if the server says it hasn't changed
    def ask(key, entry, request)
      request["if-none-match"] = entry.etag if entry # no header, for a response that has no ETag
      response = @connections.request(request)
      kept = entry.response if entry && response.instance_of?(Net::HTTPNotModified)
      keep(key, kept || response, response)
      kept || response
    end

    # Keep a response, or forget the one kept
    #
    # It's kept for as long as the latest answer says it's good for, less how long that answer says it has been kept
    # already (Age). Only a 200 is kept, and not one that says not to keep it: anything else leaves nothing kept.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param response [Net::HTTPResponse] the response to keep
    # @param latest [Net::HTTPResponse] the latest answer: the response itself, or a 304 that says it hasn't changed
    # @return [void]
    def keep(key, response, latest)
      control = latest["cache-control"].to_s
      expires = @clock.call + fresh_for(control) - latest["age"].to_i
      entry = Entry.new(response, response["etag"], expires) if response.instance_of?(Net::HTTPOK) && !NO_STORE.match?(control)
      @lock.synchronize { entry ? @entries[key] = entry : @entries.delete(key) }
    end

    # The seconds a Cache-Control says a response is good for
    #
    # @api private
    # @param control [String] the Cache-Control
    # @return [Integer] the seconds: none if it says to check each time, or doesn't say
    def fresh_for(control)
      (control[MAX_AGE, 1] unless NO_CACHE.match?(control)).to_i
    end
  end
  private_constant :Cache
end
