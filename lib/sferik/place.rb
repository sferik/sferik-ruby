# frozen_string_literal: true

require_relative "resource"

module Sferik
  # Where a talk's location is, as returned in {Talks#places}
  # @api public
  class Place < Resource
    # @!method lat
    #   The latitude, in degrees
    #   @api public
    #   @return [Numeric] the latitude, in degrees
    #   @example
    #     place.lat # => 41.39
    attribute :lat

    # @!method lon
    #   The longitude, in degrees
    #   @api public
    #   @return [Numeric] the longitude, in degrees
    #   @example
    #     place.lon # => 2.17
    attribute :lon

    # @!method country
    #   The country it's in
    #   @api public
    #   @return [String] the country it's in
    #   @example
    #     place.country # => "Spain"
    attribute :country
  end
end
