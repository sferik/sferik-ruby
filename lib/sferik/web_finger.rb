# frozen_string_literal: true

require_relative "resource"
require_relative "web_finger/link"

module Sferik
  # Where an account at sferik.net points to, as returned by {API::ProfileEndpoints#webfinger}
  #
  # It's a JSON Resource Descriptor, as WebFinger (RFC 7033) answers with: the account on Mastodon, which makes the
  # domain a fediverse handle.
  #
  # @api public
  class WebFinger < Resource
    # @!method subject
    #   The account this one points to, as an acct: URI
    #   @api public
    #   @return [String] the account this one points to, as an acct: URI
    #   @example
    #     webfinger.subject # => "acct:sferik@mastodon.social"
    attribute :subject

    # @!method aliases
    #   The URLs the account goes by
    #   @api public
    #   @return [Array<String>] the URLs the account goes by
    #   @example
    #     webfinger.aliases # => ["https://mastodon.social/@sferik", "https://mastodon.social/users/sferik"]
    list :aliases

    # @!method links
    #   What the account links to
    #
    #   That's its profile page, itself as ActivityPub, and where to follow it.
    #
    #   @api public
    #   @return [Array<Link>] what the account links to
    #   @example
    #     webfinger.links # => [#<Sferik::WebFinger::Link ...>, ...]
    list :links, "links", type: Link

    inspect_with :subject
  end
end
