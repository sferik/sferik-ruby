# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class WebFinger < Resource
    # Something an account links to, as returned in {WebFinger#links}
    #
    # A link has a URL or a template for one, not both.
    #
    # @api public
    class Link < Resource
      # @!method rel
      #   What the link is to the account
      #   @api public
      #   @return [String] what the link is to the account
      #   @example
      #     link.rel # => "http://webfinger.net/rel/profile-page"
      attribute :rel

      # @!method type
      #   The media type of what's at the URL
      #   @api public
      #   @return [String, nil] the media type of what's at the URL, or nil for a link with a template
      #   @example
      #     link.type # => "text/html"
      attribute :type

      # @!method href
      #   The URL
      #   @api public
      #   @return [String, nil] the URL, or nil for a link with a template
      #   @example
      #     link.href # => "https://mastodon.social/@sferik"
      attribute :href

      # @!method template
      #   A template for a URL, with the account to follow from as {uri}
      #   @api public
      #   @return [String, nil] the template, or nil for a link with a URL
      #   @example
      #     link.template # => "https://mastodon.social/authorize_interaction?uri={uri}"
      attribute :template
    end
  end
end
