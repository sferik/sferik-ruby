# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # A volunteer role, as returned in {Resume#volunteer}
    # @api public
    class Volunteer < Resource
      # @!method position
      #   The role
      #   @api public
      #   @return [String] the role
      #   @example
      #     role.position # => "Board of Directors"
      attribute :position

      # @!method organization
      #   The organization
      #   @api public
      #   @return [String] the organization
      #   @example
      #     role.organization # => "Pacific Primary"
      attribute :organization

      # @!method start_date
      #   When it started, as the first day of the month or year given
      #   @api public
      #   @return [Date] when it started, as the first day of the month or year given
      #   @example
      #     role.start_date # => #<Date: 2023-09-01>
      timestamp :start_date, PartialDate

      # @!method end_date
      #   When it ended, or nil if it hasn't
      #   @api public
      #   @return [Date, nil] when it ended, or nil if it hasn't
      #   @example
      #     role.end_date # => #<Date: 2026-01-01>
      timestamp :end_date, PartialDate

      # @!method summary
      #   What Erik did
      #   @api public
      #   @return [String, nil] what Erik did
      #   @example
      #     role.summary # => "President 2025–2026, Treasurer 2024–2025..."
      attribute :summary

      # @!method url
      #   The organization's site
      #   @api public
      #   @return [String, nil] the organization's site
      #   @example
      #     role.url # => "https://pacificprimary.org"
      attribute :url
    end
  end
end
