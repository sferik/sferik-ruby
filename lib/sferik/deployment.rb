# frozen_string_literal: true

require_relative "resource"

module Sferik
  # The commit of the site that's deployed, as returned by {API::SiteEndpoints#deployment}
  #
  # A copy of the site that wasn't deployed, like one run by hand, has nil for each.
  #
  # @api public
  class Deployment < Resource
    # @!method commit
    #   The SHA of the commit
    #   @api public
    #   @return [String, nil] the SHA of the commit
    #   @example
    #     deployment.commit # => "6a34226a3f351a78339b75430055a018ac30c964"
    attribute :commit

    # @!method deployed
    #   When it was deployed
    #   @api public
    #   @return [Time, nil] when it was deployed
    #   @example
    #     deployment.deployed # => 2026-10-07 18:04:11 UTC
    timestamp :deployed, Time

    # @!method url
    #   The commit, on GitHub
    #   @api public
    #   @return [String, nil] the commit, on GitHub
    #   @example
    #     deployment.url # => "https://github.com/sferik/sferik-web/commit/6a34226a3f351a78339b75430055a018ac30c964"
    attribute :url
  end
end
