# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # Where Erik lives, as returned in {Basics#location}
    # @api public
    class Location < Resource
      # @!method city
      #   The city
      #   @api public
      #   @return [String] the city
      #   @example
      #     location.city # => "San Francisco"
      attribute :city

      # @!method region
      #   The state
      #   @api public
      #   @return [String] the state
      #   @example
      #     location.region # => "California"
      attribute :region

      # @!method country_code
      #   The ISO 3166 country code
      #   @api public
      #   @return [String] the ISO 3166 country code
      #   @example
      #     location.country_code # => "US"
      attribute :country_code
    end
  end
end
