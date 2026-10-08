# frozen_string_literal: true

require "net/http"
require_relative "freshness"

module Sferik
  # Keeps the responses to a client's GET requests, and asks again only for what may have changed
  #
  # It stands where the client's {Connections} do, and makes its requests over them. A response says how long it's
  # good for (Cache-Control: max-age), and for that long the same URL asked for as the same media type is answered
  # with it, and no request is made. After that, the request says which version is kept (If-None-Match, with the
  # response's ETag), and the server answers 304 Not Modified, without a body, if that's still the one. A response
  # that says not to keep it (no-store) isn't kept, and one that says to check each time (no-cache) is checked each
  # time. Only a 200 is kept, and what's kept stays kept when the server answers with an error of its own (a 5xx),
  # which says nothing of whether it has changed: the next request asks again.
  #
  # A response that has already been kept somewhere on its way, as one from Cloudflare's cache has, says for how long
  # (Age), and is good for that much less. One that comes older than it's good for is asked for once more, at once,
  # with a request that says not to answer from a cache: the cache on its way answers with what it has while it
  # fetches another, which is the one to have, and the site makes that request wait for it. And a cache that's told to (stale) answers with a response that's no longer
  # good, when the server can't be asked whether it has changed, or answers with an error of its own.
  #
  # Threads that ask for the same thing at once, when it isn't kept or is no longer good, make one request between
  # them: the first asks, and the rest wait for its answer, which is theirs too. If it gets none, each asks for itself.
  #
  # A hundred responses are kept at most: one more, and the one that was asked of the server longest ago is forgotten.
  #
  # What a client makes of a response (the JSON parsed, and a resource built of it) is kept with the response, and
  # made once: see {#made}.
  #
  # @api private
  class Cache
    # A response that's kept, with its ETag, if it has one, when on the clock it's good until, and what was made of it
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
    # @!attribute [r] made
    #   What was made of the response
    #   @api private
    #   @return [Object, nil] what {Cache#made}'s block returned, or nil if nothing has been made of it yet
    Entry = Data.define(:response, :etag, :expires, :made)
    private_constant :Entry

    # A request on its way, whose answer is for every thread that asks for the same thing before it comes
    #
    # @api private
    class Flight
      # Initialize a flight, which hasn't landed
      #
      # @api private
      # @return [Flight] the flight
      def initialize
        @landed = Queue.new
      end

      # Make the request, and say what it got
      #
      # That's said to the threads that are waiting, and to any that ask later.
      #
      # @api private
      # @yield the request to make
      # @yieldreturn [Net::HTTPResponse] the response
      # @return [Net::HTTPResponse] the response
      def fly
        @response = yield
      ensure
        @landed.close
      end

      # Wait for the request to get its answer, and return it
      #
      # @api private
      # @return [Net::HTTPResponse, nil] the response, or nil if the request got none
      def response
        @landed.deq
        @response
      end
    end
    private_constant :Flight

    # The time, in seconds, on a clock that only goes forward
    CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    private_constant :CLOCK

    # The most responses to keep: far more than the API has, but an end to what a client keeps of URLs that are made
    # up as it goes, each with a query of its own
    LIMIT = 100
    private_constant :LIMIT

    # Initialize a cache
    #
    # @api private
    # @param connections [Connections, Cache] what to make requests over
    # @param clock [#call] what tells the time, in seconds
    # @param entries [Hash{Array => Entry}] the responses kept, by URL and media type
    # @param lock [Mutex] what's held to read or change them, and the requests on their way
    # @param stale [Boolean] whether to answer with a response that's no longer good, when the server can't be reached,
    #   or answers with an error of its own
    # @return [Cache] the cache
    def initialize(connections, clock = CLOCK, entries = {}, lock = Mutex.new, stale: false)
      @connections = connections
      @clock = clock
      @entries = entries
      @lock = lock
      @flights = {} #: Hash[key, Flight]
      @stale = stale
    end

    # Yield a cache of the same responses over connections that are kept open
    #
    # It's this cache in all but its connections: what one keeps, the other has, and a request of one's that's on its
    # way is one the other waits for.
    #
    # @api private
    # @yield [cache] the requests to make
    # @yieldparam cache [Cache] a cache whose connections are kept open
    # @yieldreturn [Object] anything
    # @return [Object] what the block returns
    def keeping
      @connections.keeping { |kept| yield dup.over(kept) }
    end

    # Close the connections requests are made over, and keep the responses
    #
    # @api private
    # @return [nil]
    def close = @connections.close

    # Send a request, unless it's a GET whose response is kept and still good
    #
    # @api private
    # @param request [Net::HTTPRequest] the request, to a URL
    # @return [Net::HTTPResponse] the response, which may be one that was kept, or the server's error if the cache isn't
    #   to answer with what's kept instead
    # @raise [NetworkError] if the server can't be reached, or its response can't be read, and there's no response
    #   kept to answer with instead, or the cache isn't to
    def request(request)
      return @connections.request(request) unless request.instance_of?(Net::HTTP::Get)

      key = [request.uri, request.fetch("accept")] #: key
      entry = @lock.synchronize { @entries[key] }
      (entry && @clock.call < entry.expires) ? entry.response : share(key) { renew(key, entry, request) }
    end

    # What a block makes of a response, which is made once of a response that's kept
    #
    # The cache answers with a response it keeps again and again, and what's made of it would be the same each time:
    # so that's kept with it, and the block isn't called again until another response is. It should make something
    # that can't be changed, since every caller gets the same one.
    #
    # @api private
    # @param uri [URI::HTTP] the URL that was asked for
    # @param accept [String] the media type it was asked for as
    # @param response [Net::HTTPResponse] the response that came
    # @yield what to make of the response
    # @yieldreturn [Object] what's made of it, which isn't nil or false
    # @return [Object] what the block returned: this time, or the first time for this response
    def made(uri, accept, response)
      key = [uri, accept] #: key
      entry = @lock.synchronize { @entries[key] }
      return yield unless entry && entry.response.equal?(response)

      entry.made || remember(key, entry, yield)
    end

    protected

    # Make this cache's requests over other connections
    #
    # @api private
    # @param connections [Connections, Cache] the connections
    # @return [Cache] the cache itself
    def over(connections)
      @connections = connections
      self
    end

    private

    # Make a request, unless one for the same thing is on its way
    #
    # Then wait for that one, and answer with what it gets. If it gets no answer, the request is made after all.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @yield the request to make
    # @yieldreturn [Net::HTTPResponse] the response
    # @return [Net::HTTPResponse] the response: this request's, or the one that was on its way
    def share(key, &ask)
      mine = Flight.new
      flight = @lock.synchronize { @flights[key] ||= mine }
      return flight.response || ask.call unless flight.equal?(mine)

      lead(key, mine, &ask)
    end

    # Make a request that other threads may be waiting for, and tell them what it gets
    #
    # It's no longer on its way before they're told, so that a thread that asks after it has landed starts another.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param flight [Flight] the request on its way
    # @yield the request to make
    # @yieldreturn [Net::HTTPResponse] the response
    # @return [Net::HTTPResponse] the response
    def lead(key, flight, &ask)
      flight.fly do
        ask.call
      ensure
        @lock.synchronize { @flights.delete(key) }
      end
    end

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
    # The request says which version of its response is kept, so that the server sends a body only for another. An
    # error of the server's own (a 5xx) leaves what's kept as it is, to be asked after again.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param entry [Entry, nil] the response kept, which is no longer good, if there is one
    # @param request [Net::HTTP::Get] the request
    # @return [Net::HTTPResponse] the response: the one kept, if the server says it hasn't changed, or answers with
    #   an error of its own and the cache answers with what's no longer good
    def ask(key, entry, request)
      request["if-none-match"] = entry.etag if entry # no header, for a response that has no ETag
      response = @connections.request(request)
      return spared(entry, response) if entry && response.is_a?(Net::HTTPServerError)

      answer = renewed(key, entry, response)
      Freshness.spent?(response) ? again(key, request, answer) : answer
    end

    # Ask once more for a response that came older than it's good for
    #
    # A cache on its way answered with what it had at once, and fetches another for whoever asks next. But asked
    # again at once, it hasn't got that one yet, as often as not: so this request says not to be answered from a
    # cache (Cache-Control: no-cache), which the site takes to mean that it should wait for the new one. What comes
    # back is kept, whatever its age, and isn't asked after a third time. If nothing does, or an error of the
    # server's own, the first answer stands.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param request [Net::HTTP::Get] the request, to send again
    # @param answer [Net::HTTPResponse] what the first answer came to
    # @return [Net::HTTPResponse] the response: the second answer's, or the first's if no second came
    def again(key, request, answer)
      entry = @lock.synchronize { @entries[key] }
      request["if-none-match"] = entry&.etag # no header, when nothing was kept, or it has no ETag
      request["cache-control"] = "no-cache"
      response = @connections.request(request)
      response.is_a?(Net::HTTPServerError) ? answer : renewed(key, entry, response)
    rescue NetworkError
      answer
    end

    # Keep what the server answers with, or go on keeping what it says hasn't changed
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param entry [Entry, nil] the response kept, which is no longer good, if there is one
    # @param response [Net::HTTPResponse] the server's answer
    # @return [Net::HTTPResponse] the response: the one kept, if the server says it hasn't changed
    def renewed(key, entry, response)
      kept = entry if response.instance_of?(Net::HTTPNotModified)
      latest = kept ? kept.with(expires: expiry(response)) : Entry.new(response, response["etag"], expiry(response), nil)
      keep(key, latest, response)
      latest.response
    end

    # Keep what was made of a response with it, if it's still the one that's kept
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param entry [Entry] the response kept, when it was made
    # @param made [Object] what was made of it
    # @return [Object] what was made of it
    def remember(key, entry, made)
      @lock.synchronize { @entries[key] = entry.with(made:) if @entries[key].equal?(entry) }
      made
    end

    # What to answer with when the server fails, and a response is kept
    #
    # The server fails when it answers with an error of its own (a 5xx).
    #
    # @api private
    # @param entry [Entry] the response kept, which is no longer good
    # @param response [Net::HTTPResponse] the server's error
    # @return [Net::HTTPResponse] the response kept, for a cache that answers with what's no longer good (stale), or
    #   else the error
    def spared(entry, response)
      @stale ? entry.response : response
    end

    # Keep a response, or forget the one kept
    #
    # Only a 200 is kept, and not one that says not to keep it: anything else leaves nothing kept. (An error of the
    # server's own, with a response kept, never gets here.) One that's kept is the latest, whether or not one was
    # kept for the same thing before.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for
    # @param entry [Entry] the response to keep, with when it's good until
    # @param answer [Net::HTTPResponse] the latest answer: the response itself, or a 304 that says it hasn't changed
    # @return [void]
    def keep(key, entry, answer)
      keepable = entry.response.instance_of?(Net::HTTPOK) && Freshness.keepable?(answer)
      @lock.synchronize do
        @entries.delete(key)
        hold(key, entry) if keepable
      end
    end

    # Keep a response as the latest, and no more than the most there may be
    #
    # One too many, and the response kept longest ago is forgotten. The lock is held by whatever calls this.
    #
    # @api private
    # @param key [Array] the URL and the media type asked for, which nothing is kept for
    # @param entry [Entry] the response to keep
    # @return [void]
    def hold(key, entry)
      @entries[key] = entry
      @entries.shift if @entries.size > LIMIT
    end

    # When a response is good until
    #
    # That's for as long as the latest answer says it's good for, less how long that answer says it has been kept
    # already (Age).
    #
    # @api private
    # @param latest [Net::HTTPResponse] the latest answer: the response itself, or a 304 that says it hasn't changed
    # @return [Numeric] the time on the cache's clock, in seconds
    def expiry(latest)
      @clock.call + Freshness.left(latest)
    end
  end
  private_constant :Cache
end
