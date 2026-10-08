# frozen_string_literal: true

require_relative "resource"
require_relative "status/github"
require_relative "status/loaded"

module Sferik
  # Whether the site's live numbers come as they should, as returned by {API::SiteEndpoints#status}
  #
  # The site asks GitHub for the contributions, the stars, and the latest push in one request, with a token. If that
  # fails, it asks for each another way, without the token, and the numbers come all the same: {Contributions#live?}
  # and {Projects#live?} are still true. So this says what became of asking with the token, which nothing else does.
  # And it says when each live value was last loaded: the stars and the latest push too, which say so nowhere else.
  #
  # @api public
  class Status < Resource
    # @!method github
    #   What became of asking GitHub with the site's token
    #   @api public
    #   @return [GitHub, nil] what became of asking GitHub with the site's token
    #   @example
    #     status.github.answered # => 2026-10-08 21:45:07 UTC
    attribute :github, type: GitHub

    # @!method loaded
    #   When the site last loaded each of its live values
    #   @api public
    #   @return [Loaded, nil] when the site last loaded each of its live values
    #   @example
    #     status.loaded.stars # => 2026-10-08 21:45:07 UTC
    attribute :loaded, type: Loaded
  end
end
