# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # What the resume says about itself, as returned by {Resume#meta}
    # @api public
    class Meta < Resource
      # @!method canonical
      #   Where the resume lives, if it says
      #   @api public
      #   @return [String, nil] where the resume lives, if it says
      #   @example
      #     meta.canonical # => "https://sferik.net/resume"
      attribute :canonical

      # @!method version
      #   The version of the resume, if it has one
      #   @api public
      #   @return [String, nil] the version of the resume, if it has one
      #   @example
      #     meta.version # => "v1.0.0"
      attribute :version

      # @!method last_modified
      #   When the resume last changed, if it says
      #   @api public
      #   @return [Date, nil] when the resume last changed, if it says
      #   @example
      #     meta.last_modified # => #<Date: 2026-10-01>
      timestamp :last_modified, PartialDate
    end
  end
end
