# frozen_string_literal: true

require_relative "resource"
require_relative "status/github"

module Sferik
  # Whether the site's live numbers come as they should, as returned by {API::SiteEndpoints#status}
  #
  # The site asks GitHub for the contributions, the stars, and the latest push in one request, with a token. If that
  # fails, it asks for each another way, without the token, and the numbers come all the same: {Contributions#live?}
  # and {Projects#live?} are still true. So this says what became of asking with the token, which nothing else does.
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
  end
end
