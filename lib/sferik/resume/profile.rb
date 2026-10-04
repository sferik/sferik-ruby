# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # A profile elsewhere, as returned in {Basics#profiles}
    # @api public
    class Profile < Resource
      # @!method network
      #   The network
      #   @api public
      #   @return [String] the network
      #   @example
      #     profile.network # => "GitHub"
      attribute :network

      # @!method username
      #   The username there
      #   @api public
      #   @return [String] the username there
      #   @example
      #     profile.username # => "sferik"
      attribute :username

      # @!method url
      #   The profile
      #   @api public
      #   @return [String] the profile
      #   @example
      #     profile.url # => "https://github.com/sferik"
      attribute :url
    end
  end
end
