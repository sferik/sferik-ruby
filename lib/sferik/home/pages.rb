# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Home < Resource
    # The paths of the site's other pages, as returned in {Home#pages}
    # @api public
    class Pages < Resource
      # @!method talks
      #   The talks page
      #   @api public
      #   @return [String] the talks page
      #   @example
      #     pages.talks # => "/talks"
      attribute :talks

      # @!method resume
      #   The resume page
      #   @api public
      #   @return [String] the resume page
      #   @example
      #     pages.resume # => "/resume"
      attribute :resume
    end
  end
end
