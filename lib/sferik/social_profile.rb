# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A profile elsewhere, such as GitHub or Mastodon, as listed by {API::ProfileEndpoints#finger}
  # @api public
  class SocialProfile < Resource
    # @!method network
    #   The name of the network
    #   @api public
    #   @return [String] the name of the network
    #   @example
    #     profile.network # => "GitHub"
    attribute :network

    # @!method username
    #   The username on that network
    #   @api public
    #   @return [String] the username on that network
    #   @example
    #     profile.username # => "sferik"
    attribute :username

    # @!method url
    #   The URL of the profile
    #   @api public
    #   @return [String] the URL of the profile
    #   @example
    #     profile.url # => "https://github.com/sferik"
    attribute :url

    # @!method icon
    #   The id of the profile's icon in https://sferik.net/icons.svg
    #   @api public
    #   @return [String] the id of the profile's icon in https://sferik.net/icons.svg
    #   @example
    #     profile.icon # => "github"
    attribute :icon

    # @!method aliases
    #   The names the site's shell accepts for `open`
    #   @api public
    #   @return [Array<String>] the names the site's shell accepts for `open`
    #   @example
    #     profile.aliases # => ["github", "gh"]
    list :aliases
  end
end
