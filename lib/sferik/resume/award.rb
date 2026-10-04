# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # An honor, as returned in {Resume#awards}
    # @api public
    class Award < Resource
      # @!method title
      #   The honor
      #   @api public
      #   @return [String] the honor
      #   @example
      #     award.title # => "Ruby Hero Award"
      attribute :title

      # @!method date
      #   When it was given
      #   @api public
      #   @return [Date] when it was given
      #   @example
      #     award.date # => #<Date: 2014-04-22>
      timestamp :date, PartialDate

      # @!method awarder
      #   Who gave it
      #   @api public
      #   @return [String] who gave it
      #   @example
      #     award.awarder # => "Ruby Heroes"
      attribute :awarder

      # @!method summary
      #   What it was for
      #   @api public
      #   @return [String] what it was for
      #   @example
      #     award.summary # => "Presented at RailsConf..."
      attribute :summary
    end
  end
end
