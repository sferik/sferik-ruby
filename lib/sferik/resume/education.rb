# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # A school, as returned in {Resume#education}
    # @api public
    class Education < Resource
      # @!method institution
      #   The school
      #   @api public
      #   @return [String] the school
      #   @example
      #     school.institution # => "Carnegie Mellon University"
      attribute :institution

      # @!method location
      #   Where it is
      #   @api public
      #   @return [String] where it is
      #   @example
      #     school.location # => "Pittsburgh"
      attribute :location

      # @!method start_date
      #   When Erik started, as the first day of the month or year given
      #   @api public
      #   @return [Date] when Erik started, as the first day of the month or year given
      #   @example
      #     school.start_date # => #<Date: 2001-08-01>
      timestamp :start_date, PartialDate

      # @!method end_date
      #   When Erik finished
      #   @api public
      #   @return [Date, nil] when Erik finished
      #   @example
      #     school.end_date # => #<Date: 2005-05-01>
      timestamp :end_date, PartialDate

      # @!method highlights
      #   What Erik did there
      #   @api public
      #   @return [Array<String>] what Erik did there
      #   @example
      #     school.highlights # => ["Student Body President"]
      list :highlights

      # @!method courses
      #   Courses
      #   @api public
      #   @return [Array<String>] courses
      #   @example
      #     school.courses # => []
      list :courses
    end
  end
end
