# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Status < Resource
    # When the site last loaded each of its live values, as returned by {Status#loaded}
    #
    # {Projects#as_of} and {Contributions#as_of} say so of the downloads and the contributions, and nothing else does
    # of the stars and the latest push. One that has never been loaded is nil: on a copy of the site that's offline,
    # each is.
    #
    # @api public
    class Loaded < Resource
      # @!method gems
      #   When the downloads were last loaded, from RubyGems
      #   @api public
      #   @return [Time, nil] when the downloads were last loaded, from RubyGems
      #   @example
      #     loaded.gems # => 2026-10-08 21:45:07 UTC
      timestamp :gems, Time

      # @!method stars
      #   When the stars were last loaded, from GitHub
      #   @api public
      #   @return [Time, nil] when the stars were last loaded, from GitHub
      #   @example
      #     loaded.stars # => 2026-10-08 21:45:07 UTC
      timestamp :stars, Time

      # @!method contributions
      #   When the year of contributions was last loaded, from GitHub
      #   @api public
      #   @return [Time, nil] when the year of contributions was last loaded, from GitHub
      #   @example
      #     loaded.contributions # => 2026-10-08 21:45:07 UTC
      timestamp :contributions, Time

      # @!method push
      #   When the latest push was last loaded, from GitHub
      #   @api public
      #   @return [Time, nil] when the latest push was last loaded, from GitHub
      #   @example
      #     loaded.push # => 2026-10-08 21:45:07 UTC
      timestamp :push, Time
    end
  end
end
