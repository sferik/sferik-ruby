# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A day of GitHub contributions, as returned in {Contributions#days}
  # @api public
  class Day < Resource
    # @!method date
    #   The day
    #   @api public
    #   @return [Date] the day
    #   @example
    #     day.date # => #<Date: 2026-10-01>
    timestamp :date, Date

    # @!method count
    #   The contributions that day
    #   @api public
    #   @return [Integer] the contributions that day
    #   @example
    #     day.count # => 12
    attribute :count

    # @!method level
    #   The shade in the graph, from 0 (none) to 4 (most)
    #
    #   1 to 4 are the quartiles of the year's days with any contributions.
    #   @api public
    #   @return [Integer] the shade in the graph, from 0 (none) to 4 (most)
    #   @example
    #     day.level # => 3
    attribute :level
  end
end
