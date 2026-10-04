# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Home < Resource
    # Who the home page is about, as returned in {Home#profile}
    # @api public
    class Profile < Resource
      # @!method name
      #   The name
      #   @api public
      #   @return [String] the name
      #   @example
      #     profile.name # => "Erik Berlin"
      attribute :name

      # @!method location
      #   Where Erik lives
      #   @api public
      #   @return [String] where Erik lives
      #   @example
      #     profile.location # => "San Francisco, California"
      attribute :location

      # @!method tagline
      #   The tagline
      #   @api public
      #   @return [String] the tagline
      #   @example
      #     profile.tagline # => "I build libraries and tools software engineers depend on."
      attribute :tagline

      # @!method handle
      #   The handle used everywhere
      #   @api public
      #   @return [String] the handle used everywhere
      #   @example
      #     profile.handle # => "sferik"
      attribute :handle

      # @!method url
      #   The site
      #   @api public
      #   @return [String] the site
      #   @example
      #     profile.url # => "https://sferik.net"
      attribute :url
    end
  end
end
