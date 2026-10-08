# frozen_string_literal: true

module Sferik
  # Reads what an answer says about keeping a response: for how long it's good, and whether to keep it at all
  #
  # An answer is the response itself, or a 304 that says a response kept hasn't changed. It says how long the response
  # is good for (Cache-Control: max-age), and how long it has been kept somewhere on its way already (Age), as one
  # from Cloudflare's cache has.
  #
  # @api private
  module Freshness
    # The seconds a Cache-Control says a response is good for
    MAX_AGE = /\bmax-age=(\d+)/i
    private_constant :MAX_AGE

    # A Cache-Control that says to check a response each time it's used
    NO_CACHE = /\bno-cache\b/i
    private_constant :NO_CACHE

    # A Cache-Control that says not to keep a response
    NO_STORE = /\bno-store\b/i
    private_constant :NO_STORE

    # The seconds an answer says a response is good for
    #
    # @api private
    # @param answer [Net::HTTPResponse] the answer
    # @return [Integer] the seconds: none if it says to check each time, or doesn't say
    def self.lifetime(answer)
      control = answer["cache-control"].to_s
      (control[MAX_AGE, 1] unless NO_CACHE.match?(control)).to_i
    end

    # The seconds a response is still good for, when its answer comes
    #
    # @api private
    # @param answer [Net::HTTPResponse] the answer
    # @return [Integer] the seconds it's good for, less the whole seconds it says it has been kept already: none, or
    #   fewer, for one that's no longer good
    def self.left(answer)
      lifetime(answer) - answer["age"].to_i
    end

    # Whether a response came older than it's good for
    #
    # A cache on its way may answer with one at once, and fetch another for whoever asks next (as Cloudflare's does
    # for the site): asked again, it may have that one.
    #
    # @api private
    # @param answer [Net::HTTPResponse] the answer
    # @return [Boolean] true if it says how long the response is good for, and that it has been kept for as long
    def self.spent?(answer)
      lifetime(answer).positive? && !left(answer).positive?
    end

    # Whether an answer lets a response be kept
    #
    # @api private
    # @param answer [Net::HTTPResponse] the answer
    # @return [Boolean] false if it says not to keep the response
    def self.keepable?(answer)
      !answer["cache-control"]&.match?(NO_STORE)
    end
  end
  private_constant :Freshness
end
