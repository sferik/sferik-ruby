# frozen_string_literal: true

require "json"
require "net/http"
require "net/http/status" # the reason phrases, which net/http itself doesn't load

module Sferik
  # Base error class for all Sferik errors
  # @api public
  class Error < StandardError; end

  # Raised when a path can't be in a URL: one with a space, say
  # @api public
  class InvalidURL < Error; end

  # Raised when the server can't be reached, or its response can't be read: a timeout, a refused connection, a failed
  # DNS lookup, a TLS error, or a body that doesn't decompress
  # @api public
  class NetworkError < Error; end

  # Raised when a request was sent, or may have been, and no answer came that could be read: the connection was
  # open, and then it timed out, or closed, or what came back wasn't a response. Any other {NetworkError} is for a
  # server that couldn't be connected to, so nothing was sent.
  # @api public
  class Unanswered < NetworkError; end

  # Raised when a request is redirected more than {Client#max_redirects} times
  # @api public
  class TooManyRedirects < Error; end

  # Raised when a response isn't what the API documents, such as JSON that doesn't parse
  # @api public
  class InvalidResponse < Error; end

  # Base class for HTTP errors from the sferik.net API
  # @api public
  class HTTPError < Error
    # The media type of a response that is plain text, whatever its parameters
    PLAIN_TEXT = %r{\Atext/plain\s*(;|\z)}i
    private_constant :PLAIN_TEXT

    # A Retry-After header that gives a number of seconds
    SECONDS = /\A\d+\z/
    private_constant :SECONDS

    # The status code of an error that is built without one: none, since this class is for no status in particular
    # @api public
    CODE = nil

    # The HTTP status code
    # @api public
    # @return [Integer, nil] the HTTP status code: nil only for an error built by hand, of a class with no {CODE}
    # @example
    #   error.code # => 404
    attr_reader :code

    # The headers of the response
    # @api public
    # @return [Hash{String => String}] the headers by name, in lowercase, frozen
    # @example
    #   error.headers["content-type"] # => "application/json; charset=utf-8"
    attr_reader :headers

    # The body of the response
    # @api public
    # @return [String] the body, in the charset its Content-Type names (without one, UTF-8 if it's text or JSON, and binary
    #   if not), frozen
    # @example
    #   error.body # => "{\"error\":\"Not Found\"}"
    attr_reader :body

    # Initialize a new HTTPError
    #
    # The message is the error a JSON response body names, or else the body if it's plain text, or else the status
    # line: a page of HTML, as a proxy in front of the API may answer with, is no message. The message is in UTF-8,
    # whatever the charset of the body: bytes that aren't valid in that charset are replaced, and a body in a charset
    # that can't be read as text at all is no message either.
    #
    # Nothing is required, so that an error can be raised by hand, as a spec that stubs a request does: the code is
    # then the one the class is for (404 for {NotFound}), and the message its status line, or the class's name for a
    # class with no code.
    #
    # @api public
    # @param message [String, nil] a message to use instead: why a redirect wasn't followed, say
    # @param code [Integer, nil] the HTTP status code (defaults to the CODE of the class)
    # @param reason [String, nil] the reason phrase of the status line: "Not Found", say (defaults to the code's)
    # @param headers [Hash{String => String}] the headers of the response by name, in lowercase
    # @param body [String] the body of the response
    # @return [HTTPError] a new instance
    # @example
    #   Sferik::HTTPError.new(code: 404, reason: "Not Found", headers: {"content-type" => "text/plain"}, body: "")
    # @example Raise one by hand, with the code of its class
    #   raise Sferik::NotFound                # code 404, message "404 Not Found"
    #   raise Sferik::NotFound, "No such page"
    def initialize(message = nil, code: self.class::CODE, reason: Net::HTTP::STATUS_CODES[code], headers: {}, body: "")
      @code = code
      @headers = headers.dup.freeze
      @body = body.dup.freeze
      super(message || detail(reason))
    end

    # Which error it is, as the API names it in a JSON response body
    #
    # The two endpoints that write name theirs: "busy" and "full" for a 429 from {API::SiteEndpoints#write} (one message
    # a minute from an address, and twenty a day in all), "too_long", "empty", "undelivered", and so on.
    #
    # @api public
    # @return [String, nil] the code: nil if the body isn't JSON that names one
    # @example
    #   error.error_code # => "busy"
    def error_code
      named(utf8.scrub, "code")
    rescue Encoding::ConverterNotFoundError
      nil
    end

    # The seconds to wait before trying again
    #
    # They are what the Retry-After header of the response gives, as a 429 has, and a 502 from {API::SiteEndpoints#write}.
    #
    # @api public
    # @return [Integer, nil] the seconds: nil if the response doesn't say, or names a date rather than a number of seconds
    # @example
    #   error.retry_after # => 60
    def retry_after
      seconds = headers["retry-after"]
      seconds.to_i if SECONDS.match?(seconds)
    end

    private

    # What the response says went wrong
    #
    # @api private
    # @param reason [String, nil] the reason phrase of the status line
    # @return [String, nil] the error the body names, or else the body if that's plain text, or else the status line,
    #   if there is one
    def detail(reason)
      text = utf8.scrub.strip
      named(text, "error") || plain(text) || status_line(reason)
    rescue Encoding::ConverterNotFoundError
      status_line(reason)
    end

    # The status line of the response, without the version of HTTP
    #
    # @api private
    # @param reason [String, nil] the reason phrase
    # @return [String, nil] the code and the reason, or whichever there is, or nil if there's neither
    def status_line(reason)
      line = "#{code} #{reason}".strip
      line unless line.empty?
    end

    # The body in UTF-8, so that the message can be put in any other text
    #
    # A binary body, which is one that isn't text or JSON and whose response named no charset, is taken for UTF-8.
    #
    # @api private
    # @return [String] the body, in UTF-8
    # @raise [Encoding::ConverterNotFoundError] if the body's charset is one nothing can be converted from, like UTF-7
    def utf8
      return String.new(body, encoding: Encoding::UTF_8) if body.encoding.equal?(Encoding::BINARY)

      body.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    # What a JSON response body names
    #
    # @api private
    # @param text [String] the response body
    # @param key [String] the key: "error" or "code" (the API's errors are {"error": "Not Found", "code": "not_found"})
    # @return [String, nil] the String a JSON object has under the key, if it does
    def named(text, key)
      parsed = JSON.parse(text)
      value = parsed.fetch(key, nil) if parsed.instance_of?(Hash)
      value if value.instance_of?(String)
    rescue JSON::ParserError
      nil
    end

    # The body of a response that is plain text
    #
    # @api private
    # @param text [String] the response body
    # @return [String, nil] the body, if the response is plain text and has one
    def plain(text)
      text if PLAIN_TEXT.match?(headers["content-type"]) && !text.empty?
    end
  end

  # Raised for a 4xx response
  # @api public
  class ClientError < HTTPError
    # The status code of an error that is built without one
    # @api public
    CODE = 400
  end

  # Raised for a 404 Not Found response
  # @api public
  class NotFound < ClientError
    # The status code of an error that is built without one
    # @api public
    CODE = 404
  end

  # Raised for a 406 Not Acceptable response: the resource has no representation in the format asked for
  # @api public
  class NotAcceptable < ClientError
    # The status code of an error that is built without one
    # @api public
    CODE = 406
  end

  # Raised for a 429 Too Many Requests response: the server takes one message a minute from an address, and twenty a
  # day in all (see {API::SiteEndpoints#write}). {#retry_after} is how long to wait, and {#error_code} which limit it was.
  # @api public
  class TooManyRequests < ClientError
    # The status code of an error that is built without one
    # @api public
    CODE = 429
  end

  # Raised for a 5xx response
  # @api public
  class ServerError < HTTPError
    # The status code of an error that is built without one
    # @api public
    CODE = 500
  end
end
