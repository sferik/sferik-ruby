# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "api"
require_relative "body"
require_relative "cache"
require_relative "configuration"
require_relative "connections"
require_relative "errors"
require_relative "json_parsing"
require_relative "validation"

module Sferik
  # A client for the sferik.net API
  #
  # Each resource is one URL, and the Accept header picks its format: the endpoints of {API} ask for JSON (or, for
  # the resume, LaTeX and PDF), and {#get} asks for whatever you like. {#post} sends what the two endpoints that
  # write take: a terminal checking in, and a message.
  #
  # A thread's requests to a host are made over one connection, which is left open between them, and opened again
  # if it has sat unused: {#keep_alive} is for connections that are closed when its block ends. And each GET asks the
  # server: {#cached} is a client that keeps the responses, and asks again only for what may have changed.
  #
  # @api public
  class Client
    include API
    include JSONParsing
    include Validation

    # The encodings of a body that names no charset of its own, which is sent as it is: binary, and US-ASCII
    UNLABELED = [Encoding::BINARY, Encoding::US_ASCII].freeze
    private_constant :UNLABELED

    # The media type of the body of a POST request
    PLAIN_TEXT = "text/plain; charset=utf-8"
    private_constant :PLAIN_TEXT

    # The host for API requests
    # @api public
    # @return [String] the host, including the scheme, frozen
    # @example
    #   client.host # => "https://sferik.net"
    attr_reader :host

    # The 'User-Agent' HTTP header sent with requests
    # @api public
    # @return [String] the user agent, frozen
    # @example
    #   client.user_agent
    attr_reader :user_agent

    # The seconds to wait for a connection to open
    # @api public
    # @return [Numeric] the timeout
    # @example
    #   client.open_timeout # => 5
    attr_reader :open_timeout

    # The seconds to wait for a response
    #
    # Net::HTTP sends a request that times out once more, so a response that never comes takes twice this long to fail.
    #
    # @api public
    # @return [Numeric] the timeout
    # @example
    #   client.read_timeout # => 10
    attr_reader :read_timeout

    # The seconds to wait for a request to be sent
    #
    # Net::HTTP has no such timeout on Windows.
    #
    # @api public
    # @return [Numeric] the timeout
    # @example
    #   client.write_timeout # => 10
    attr_reader :write_timeout

    # The most redirects to follow for one request
    # @api public
    # @return [Integer] the limit, which is 0 to follow none
    # @example
    #   client.max_redirects # => 10
    attr_reader :max_redirects

    # Initialize a new client
    #
    # Every option defaults to the global configuration (see {Configuration#configure}).
    #
    # @api public
    # @param host [String] the host for API requests, including the scheme
    # @param user_agent [String] the 'User-Agent' HTTP header sent with requests
    # @param open_timeout [Numeric] the seconds to wait for a connection to open
    # @param read_timeout [Numeric] the seconds to wait for a response
    # @param write_timeout [Numeric] the seconds to wait for a request to be sent
    # @param max_redirects [Integer] the most redirects to follow for one request
    # @return [Client] a new client
    # @raise [ArgumentError] if an option isn't of the type it should be, the host isn't an http or https URL (or has
    #   credentials, a query, or a fragment), the user agent has a line break, a timeout isn't positive and finite, or
    #   max_redirects is negative
    # @example Create a client for a local copy of the site
    #   client = Sferik::Client.new(host: "http://localhost:3745")
    def initialize(host: Sferik.host, user_agent: Sferik.user_agent, open_timeout: Sferik.open_timeout, read_timeout: Sferik.read_timeout,
      write_timeout: Sferik.write_timeout, max_redirects: Sferik.max_redirects)
      @host = http_url(check(:host, host, String)).delete_suffix("/").freeze
      @user_agent = one_line(:user_agent, check(:user_agent, user_agent, String)).dup.freeze
      @open_timeout = seconds(:open_timeout, open_timeout)
      @read_timeout = seconds(:read_timeout, read_timeout)
      @write_timeout = seconds(:write_timeout, write_timeout)
      @max_redirects = not_negative(:max_redirects, check(:max_redirects, max_redirects, Integer))
      freeze
    end

    # Perform a GET request and return the response body
    #
    # The path is always one on {#host}, even if it looks like a URL of its own. Redirects are followed, up to
    # {#max_redirects}, to http and https URLs, but never from https to http.
    #
    # @api public
    # @param path [String] the path, starting with a slash
    # @param accept [String] the media type to ask for: application/json, text/plain, text/html, or, for the resume,
    #   application/x-latex or application/pdf
    # @return [String] the response body, in the charset its Content-Type names: without one, text and JSON are UTF-8, and
    #   anything else is binary, as a PDF is
    # @raise [ArgumentError] if the path or the media type isn't a String, or the media type has a line break
    # @raise [InvalidURL] if the path can't be in a URL
    # @raise [TooManyRedirects] if the request is redirected more than {#max_redirects} times
    # @raise [NotAcceptable] if the resource has no representation of that type
    # @raise [NotFound] if there is no resource at that path
    # @raise [HTTPError] for any other response that isn't a success, or a redirect that isn't followed
    # @raise [Unanswered] if the server was connected to, and its response didn't come, or can't be read
    # @raise [NetworkError] if the server can't be connected to
    # @example Get the bio as terminal output
    #   Sferik.client.get("/whoami", accept: "text/plain")
    def get(path, accept: "application/json")
      Body.of(got(uri_for(check(:path, path, String)), one_line(:accept, check(:accept, accept, String))))
    end

    # Perform a POST request and return the response body
    #
    # The path is always one on {#host}, as for {#get}, and may have a query. The body is sent as plain text, in
    # UTF-8: one in another charset is converted, with a replacement character for anything that doesn't convert, and a
    # binary or US-ASCII one is taken for UTF-8 already. A redirect isn't followed, and a request that times out isn't
    # sent again, since it may have been taken: with an idempotency key, it's safe to send again yourself.
    #
    # @api public
    # @param path [String] the path, starting with a slash, with any query
    # @param body [String] the body of the request, as plain text (defaults to none)
    # @param accept [String] the media type to ask for: application/json or text/plain
    # @param idempotency_key [String, nil] a random key, one per message, of 16 to 64 letters, digits, underscores, and
    #   hyphens: /write takes the same key again for the same message, and doesn't send it twice
    # @return [String] the response body, in the charset its Content-Type names: without one, text and JSON are UTF-8, and
    #   anything else is binary
    # @raise [ArgumentError] if the path, the body, the media type, or the key isn't a String, the media type or the key
    #   has a line break, or the body is in a charset that doesn't convert to UTF-8, like UTF-7
    # @raise [InvalidURL] if the path can't be in a URL
    # @raise [NotFound] if there is no resource at that path
    # @raise [TooManyRequests] if the server has taken too many requests
    # @raise [HTTPError] for any other response that isn't a success, including a redirect
    # @raise [Unanswered] if the server was connected to, and its response didn't come, or can't be read
    # @raise [NetworkError] if the server can't be connected to
    # @example Check in a terminal, and get the response as it is
    #   Sferik.client.post("/who?token=0123456789abcdef&page=/")
    def post(path, body = "", accept: "application/json", idempotency_key: nil)
      request = Net::HTTP::Post.new(uri_for(check(:path, path, String)), post_headers(accept, idempotency_key))
      request.body = utf8(check(:body, body, String))
      Body.of(success(connections.request(request)))
    end

    # Make the requests in a block over connections that are closed when it ends
    #
    # A client makes each thread's requests to a host over one connection, which saves connecting again (with https,
    # most of the time a request takes), and leaves it open for the thread's next: it's closed when the thread is
    # collected, or the process ends, or by {#close}. The client this yields opens connections of its own instead, one per host, and
    # closes them when the block ends, for when one mustn't be left open. Either way, Net::HTTP opens one again that
    # has sat unused for more than half a minute, or that the server has closed by then. The client yielded is for
    # one thread at a time, as a connection is, and after the block it's a client like any other.
    #
    # @api public
    # @yield [client] the requests to make
    # @yieldparam client [Client] a client with the same options, and connections of its own
    # @yieldreturn [Object] anything
    # @return [Object] what the block returns
    # @raise [ArgumentError] if no block is given
    # @example Get the bio, the talks, and the resume over one connection, and close it
    #   Sferik.client.keep_alive { |client| [client.whoami, client.talks, client.resume] }
    def keep_alive
      raise ArgumentError, "keep_alive must be given a block" unless block_given?

      connections.keeping { |kept| yield dup.keep(kept) }
    end

    # Close the connections this thread has open
    #
    # A thread's requests are made over connections that are left open for its next, and closed when the thread is
    # collected, or the process ends. This closes them now: before a fork, say, or when a long-lived process is done
    # with the site for a while. The next request opens one again. They're the thread's, not this client's alone: any
    # client's requests on this thread were made over them. On the client {#keep_alive} yields, it's that block's
    # connections that are closed. What a {#cached} client has kept of the responses stays kept.
    #
    # @api public
    # @return [nil]
    # @example Close the connection before forking, so the child opens its own
    #   Sferik.whoami
    #   Sferik.client.close
    #   fork { Sferik.talks }
    def close = connections.close

    # A client that keeps the responses to its GET requests
    #
    # It asks again only for what may have changed. A response says how long it's good for (most of the API's, an
    # hour, and five minutes for what has live numbers in it), and for that long the client answers with it, without
    # a request. After that it asks with the response's ETag, and the server sends the body only if it has changed.
    # What's kept is by URL and media type, in memory, for as long as the client is (a hundred responses at most, the
    # latest it asked for), and is safe to share between threads: keep the client, since each call of this starts
    # with nothing kept. Threads that ask for the same thing at once, when it isn't kept or is no longer good, make
    # one request between them: the first asks, and the rest wait for its answer.
    #
    # What an endpoint builds of a response is kept with it, so for as long as a response is answered with, the
    # endpoint returns the same object, and the JSON isn't parsed again.
    #
    # A response that Cloudflare's cache answered with has been kept there for a while already, which it says (Age),
    # and is good for that much less here. One that comes older than it's good for is asked for once more, at once:
    # that cache answers with what it has while it builds another, and the second request gets that one.
    #
    # When the server can't be reached, or doesn't answer, to say whether a response that's no longer good has
    # changed, the request fails with a {NetworkError}, as any other would, and when it answers with an error of its
    # own (a 5xx), with a {ServerError}. The response stays kept either way, to be asked after again. With
    # stale_if_error, the client answers with the response it kept instead, however old: for a script that would
    # rather go on with what it last knew.
    #
    # @api public
    # @param stale_if_error [Boolean] whether to answer with a response that's no longer good when the server can't
    #   be reached, doesn't answer, or answers with an error of its own
    # @return [Client] a client with the same options, and a cache of its own
    # @raise [ArgumentError] if stale_if_error is neither true nor false
    # @example Ask who's reading the site every second, which asks the server every five
    #   client = Sferik.client.cached
    #   loop { puts client.who.size; sleep 1 }
    # @example Go on with the last answer when the network is down, or the server is
    #   client = Sferik.client.cached(stale_if_error: true)
    def cached(stale_if_error: false) = dup.keep(Cache.new(connections, stale: boolean(:stale_if_error, stale_if_error)))

    # A short description of the client, without the user agent
    #
    # @api public
    # @return [String] the description
    # @example
    #   client.inspect # => "#<Sferik::Client https://sferik.net>"
    def inspect = "#<#{self.class} #{host}>"

    # Perform a GET request, and return what a block makes of the JSON that comes back
    #
    # It's what the endpoints of {API} build their resources with. A {#cached} client answers with the response it
    # kept for as long as it's good, and with what was made of it too: the JSON isn't parsed again, nor the resource
    # built, until the response is another. Everything an endpoint returns is frozen all the way down, so it's safe
    # for every caller to have the same one.
    #
    # @api private
    # @param path [String] the path, starting with a slash, with any query
    # @param accept [String] the media type to ask for, which is JSON of some kind
    # @yield [attributes] what to make of the response
    # @yieldparam attributes [Hash{String => Object}] the parsed JSON, deep-frozen
    # @yieldreturn [Object] what's made of it, which can't be changed
    # @return [Object] what the block returned: this time, or the first time for this response
    # @raise [InvalidResponse] if the response isn't a JSON object
    # @raise [Error] if the request fails, as {#get} raises
    def json(path, accept: "application/json")
      uri = uri_for(path)
      response = got(uri, accept)
      connections.made(uri, accept, response) { yield parse_json(Body.of(response)) }
    end

    protected

    # Make this client's requests over other connections, and freeze it again
    #
    # @api private
    # @param connections [Connections, Cache] the connections, or a cache over them
    # @return [Client] the client itself
    def keep(connections)
      @connections = connections
      freeze
    end

    private

    # Send a GET request, following redirects, for a response that's a success
    #
    # @api private
    # @param uri [URI::HTTP] the URL
    # @param accept [String] the media type to ask for
    # @return [Net::HTTPResponse] the response
    # @raise [HTTPError] if the response isn't a success
    def got(uri, accept) = success(fetch(uri, accept, max_redirects))

    # A response that's a success, or else its error
    #
    # @api private
    # @param response [Net::HTTPResponse] the response
    # @return [Net::HTTPResponse] the response
    # @raise [HTTPError] if the response isn't a success
    def success(response) = response.is_a?(Net::HTTPSuccess) ? response : raise(error_for(response))

    # The connections requests are made over
    #
    # Those {#keep_alive} gave this client, which it closes, or else ones the thread keeps open.
    #
    # @api private
    # @return [Connections] the connections
    def connections = @connections || Connections.new({open_timeout:, read_timeout:, write_timeout:})

    # The URL of a path on the host
    #
    # @api private
    # @param path [String] the path
    # @return [URI::HTTP] the URL
    # @raise [InvalidURL] if the path can't be in a URL
    def uri_for(path)
      url = "#{host}/#{path.delete_prefix("/")}"
      URI.parse(url)
    rescue URI::InvalidURIError
      raise InvalidURL, "#{url.inspect} isn't a valid URL"
    end

    # Send a GET request, following redirects
    #
    # @api private
    # @param uri [URI::HTTP] the URL
    # @param accept [String] the media type to ask for
    # @param redirects [Integer] the redirects left to follow
    # @return [Net::HTTPResponse] the last response
    # @raise [TooManyRedirects] if there's another redirect when none are left
    def fetch(uri, accept, redirects)
      response = connections.request(Net::HTTP::Get.new(uri, headers(accept)))
      location = redirect(response, uri)
      return response unless location
      raise TooManyRedirects, "More than #{max_redirects} redirects (GET #{uri})" unless redirects.positive?

      fetch(location, accept, redirects - 1)
    end

    # Where a response redirects to
    #
    # An http or https URL, resolved against the request's: only an https one, if the request's is. One without a
    # host, like "https:/whoami", is nowhere to go, as one that isn't a URL is.
    #
    # @api private
    # @param response [Net::HTTPResponse] the response
    # @param uri [URI::HTTP] the request's URL
    # @return [URI::HTTP, nil] the URL, or nil if the response isn't a redirect, or doesn't say where to
    # @raise [HTTPError] if the redirect is to a URL that isn't followed: from https to http, or to another scheme
    def redirect(response, uri)
      return unless response.is_a?(Net::HTTPRedirection)

      location = response["location"]
      return unless location

      target = URI.join(uri, location)
      # URI::HTTPS is a URI::HTTP, so http may go to https, but not https to http
      raise error_for(response, "Refused to follow a redirect from #{uri} to #{target}") unless target.is_a?(uri.class)

      target unless target.host.to_s.empty?
    rescue URI::InvalidURIError
      nil
    end

    # The body of a request in UTF-8, which is the charset it's sent as
    #
    # A binary body is taken for UTF-8 already, and so is a US-ASCII one: what Ruby reads with no locale set, as in
    # cron or a container, is labeled US-ASCII whatever its bytes are, and US-ASCII that is valid is UTF-8 as it is.
    # Bytes that aren't valid in the body's charset, and characters UTF-8 doesn't have, are replaced.
    #
    # @api private
    # @param body [String] the body
    # @return [String] the body, in UTF-8, or as it is if it's binary or US-ASCII
    # @raise [ArgumentError] if the body's charset is one nothing can be converted from, like UTF-7
    def utf8(body)
      return body if UNLABELED.include?(body.encoding)

      body.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    rescue Encoding::ConverterNotFoundError
      raise ArgumentError, "body must be in a charset that converts to UTF-8, not #{body.encoding}"
    end

    # The headers of every request
    #
    # @api private
    # @param accept [String] the media type to ask for
    # @return [Hash{String => String}] the headers
    def headers(accept) = {"Accept" => accept, "User-Agent" => user_agent}

    # The headers of a POST request
    #
    # @api private
    # @param accept [Object] the media type to ask for
    # @param key [Object] the idempotency key, or nil for none
    # @return [Hash{String => String}] the headers
    # @raise [ArgumentError] if the media type or the key isn't a String, or has a line break
    def post_headers(accept, key)
      one_line(:idempotency_key, check(:idempotency_key, key, String)) unless key.nil?
      headers(one_line(:accept, check(:accept, accept, String))).merge({"Content-Type" => PLAIN_TEXT, "Idempotency-Key" => key}.compact)
    end

    # The error for a response that isn't a success
    #
    # @api private
    # @param response [Net::HTTPResponse] the response
    # @param message [String, nil] a message to use instead of what the response says
    # @return [HTTPError] the error
    def error_for(response, message = nil)
      error_class(response).new(message, code: Integer(response.code), reason: response.message, headers: response.each_header.to_h, body: Body.of(response))
    end

    # The class of error for a response that isn't a success
    #
    # @api private
    # @param response [Net::HTTPResponse] the response
    # @return [Class] the class
    def error_class(response)
      case response
      when Net::HTTPNotFound then NotFound
      when Net::HTTPNotAcceptable then NotAcceptable
      when Net::HTTPTooManyRequests then TooManyRequests
      when Net::HTTPClientError then ClientError
      when Net::HTTPServerError then ServerError
      else HTTPError
      end
    end
  end
end
