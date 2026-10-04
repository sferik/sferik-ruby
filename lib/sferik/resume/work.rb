# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # A job, as returned in {Resume#work}
    # @api public
    class Work < Resource
      # @!method position
      #   The title
      #   @api public
      #   @return [String] the title
      #   @example
      #     work.position # => "Software Engineering Manager"
      attribute :position

      # @!method name
      #   The company
      #   @api public
      #   @return [String] the company
      #   @example
      #     work.name # => "Twitter"
      attribute :name

      # @!method start_date
      #   When it started, as the first day of the month or year given
      #   @api public
      #   @return [Date] when it started, as the first day of the month or year given
      #   @example
      #     work.start_date # => #<Date: 2021-01-01>
      timestamp :start_date, PartialDate

      # @!method end_date
      #   When it ended, or nil if it hasn't
      #   @api public
      #   @return [Date, nil] when it ended, or nil if it hasn't
      #   @example
      #     work.end_date # => #<Date: 2023-01-01>
      timestamp :end_date, PartialDate

      # @!method highlights
      #   What Erik did there
      #   @api public
      #   @return [Array<String>] what Erik did there
      #   @example
      #     work.highlights # => ["Led the engineering team that built Subscriptions..."]
      list :highlights
    end
  end
end
