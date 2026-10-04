# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # A patent, as returned in {Resume#patents} (an addition to JSON Resume)
    # @api public
    class Patent < Resource
      # @!method title
      #   The title
      #   @api public
      #   @return [String] the title
      #   @example
      #     patent.title # => "Method and system for dynamic advertising based on user actions"
      attribute :title

      # @!method number
      #   The publication number
      #   @api public
      #   @return [String] the publication number
      #   @example
      #     patent.number # => "US20110153414A1"
      attribute :number

      # @!method date
      #   When it was published
      #   @api public
      #   @return [Date] when it was published
      #   @example
      #     patent.date # => #<Date: 2011-06-23>
      timestamp :date, PartialDate

      # @!method url
      #   The patent on Google Patents
      #   @api public
      #   @return [String] the patent on Google Patents
      #   @example
      #     patent.url # => "https://patents.google.com/patent/US20110153414A1"
      attribute :url
    end
  end
end
