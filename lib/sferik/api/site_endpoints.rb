# frozen_string_literal: true

require "securerandom"
require "uri"
require_relative "../json_parsing"
require_relative "../validation"
require_relative "../who"

module Sferik
  module API
    # The endpoints about the site itself: who's reading it, checking in as one of them, sending Erik a message, any
    # page as terminal output, and the API's description
    # @api public
    module SiteEndpoints
      include JSONParsing
      include Validation

      # Returns everyone reading the site right now
      #
      # There's a terminal per browser tab, as the shell's who lists them, and they're Enumerable: `Sferik.who.size`
      # is how many tabs have the site open.
      #
      # @api public
      # @return [Who]
      # @example
      #   Sferik.who.map(&:page) # => ["/", "/talks"]
      def who
        Who.new(parse_json(get("/who")))
      end

      # Checks in a terminal, and returns everyone reading the site
      #
      # It's what each browser tab does when it opens, and every minute it's in view. A terminal is logged in for
      # three minutes after it last checked in, and keeps its name for as long as it checks in with the same token.
      #
      # @api public
      # @param token [String] a random token, one per terminal, of 16 to 64 letters, digits, underscores, and hyphens
      # @param page [String] the page the terminal is on: "/", "/talks", or "/resume"
      # @return [Who] everyone reading the site, with the terminal that checked in as {Who#you}
      # @raise [ArgumentError] if the token or the page isn't a String
      # @raise [ClientError] if the token isn't one, or there's no such page: {HTTPError#error_code} is "bad_token" or
      #   "bad_page"
      # @example
      #   Sferik.check_in(SecureRandom.uuid).you # => "ttys001"
      # @example Check in on another page
      #   Sferik.check_in(SecureRandom.uuid, page: "/talks")
      def check_in(token, page: "/")
        query = URI.encode_www_form(token: check(:token, token, String), page: check(:page, page, String))
        Who.new(parse_json(post("/who?#{query}")))
      end

      # Sends Erik a message, as the shell's write sferik does
      #
      # The message is emailed on, with a Reply-To if it includes an email address. The server takes one message a
      # minute from an address, and twenty a day in all.
      #
      # If no answer comes, the message is sent once more, as Net::HTTP sends a GET: it goes with a key, and the server
      # doesn't email a message twice whose key it has taken within a day. To try again yourself after a
      # {NetworkError}, give the same key.
      #
      # @api public
      # @param message [String] the message, as plain text: 5,000 bytes at most, sent as UTF-8 (see {Client#post})
      # @param tty [String, nil] the sender's terminal, for the subject line: {Who#you}, from {#check_in}
      # @param key [String] a random key, one per message, of 16 to 64 letters, digits, underscores, and hyphens
      # @return [String] what the server says: "message sent to sferik"
      # @raise [ArgumentError] if the message or the key isn't a String, the message is in a charset that doesn't convert
      #   to UTF-8, or the terminal is neither a String nor nil
      # @raise [ClientError] if there's nothing to send or the key isn't one (400), or the message is too long (413)
      # @raise [TooManyRequests] if there have been too many (429): {HTTPError#retry_after} is how long to wait, and
      #   {HTTPError#error_code} is "busy" for one a minute, and "full" for twenty a day
      # @raise [ServerError] if the email didn't go through (502), or the server doesn't send email (503)
      # @raise [NetworkError] if the server can't be reached, or its response can't be read, twice
      # @raise [InvalidResponse] if the response isn't what the API documents
      # @example
      #   Sferik.write("Hello from Ruby. Reply to me@example.com")
      def write(message, tty: nil, key: SecureRandom.uuid)
        check(:tty, tty, String) unless tty.nil?
        said = parse_json(deliver("/write?#{URI.encode_www_form({tty:}.compact)}".chomp("?"), message, check(:key, key, String)))["message"]
        raise InvalidResponse, "Expected a message, got #{said.inspect}" unless said.instance_of?(String)

        said
      end

      # Returns a resource as terminal output, wrapped to 80 columns
      #
      # It's what `curl sferik.net` shows.
      #
      # @api public
      # @param path [String] the resource's path: "/whoami", "/resume" (as a man page), etc. (defaults to the home page)
      # @return [String] the text
      # @raise [NotFound] if there is no resource at that path
      # @raise [InvalidURL] if the path can't be in a URL
      # @example Print the resume as a man page
      #   puts Sferik.text("/resume")
      def text(path = "")
        get(path, accept: "text/plain")
      end

      # Returns the API's OpenAPI 3.1 description
      #
      # @api public
      # @return [Hash{String => Object}] the parsed document, deep-frozen
      # @example
      #   Sferik.openapi["paths"].keys
      def openapi
        parse_json(get("/openapi.json"))
      end

      private

      # Send a message, and once more if no answer comes: its key makes that safe
      #
      # @api private
      # @param path [String] the path, with any query
      # @param message [String] the message
      # @param key [String] the message's idempotency key
      # @return [String] the response body
      # @raise [NetworkError] if the server can't be reached, or its response can't be read, twice
      def deliver(path, message, key)
        post(path, message, idempotency_key: key)
      rescue NetworkError
        post(path, message, idempotency_key: key)
      end
    end
  end
end
