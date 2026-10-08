# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Status < Resource
    # What became of asking GitHub with the site's token, as returned by {Status#github}
    #
    # A copy of the site that has no token, or hasn't asked yet, has nil for each.
    #
    # @api public
    class GitHub < Resource
      # @!method asked
      #   When GitHub was last asked with the token
      #   @api public
      #   @return [Time, nil] when GitHub was last asked with the token
      #   @example
      #     github.asked # => 2026-10-08 21:45:07 UTC
      timestamp :asked, Time

      # @!method answered
      #   When GitHub last answered: when it was asked, if the last answer came
      #   @api public
      #   @return [Time, nil] when GitHub last answered: when it was asked, if the last answer came
      #   @example
      #     github.answered # => 2026-10-08 21:45:07 UTC
      timestamp :answered, Time

      # @!method error
      #   What went wrong the last time GitHub was asked
      #   @api public
      #   @return [String, nil] what went wrong the last time GitHub was asked, or nil if it answered
      #   @example
      #     github.error # => "https://api.github.com/graphql: 401"
      attribute :error
    end
  end
end
