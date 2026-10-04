# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # Open source work, as returned in {Resume#projects}
    # @api public
    class Project < Resource
      # @!method name
      #   The projects
      #   @api public
      #   @return [String] the projects
      #   @example
      #     project.name # => "RubyGems.org"
      attribute :name

      # @!method description
      #   What Erik did
      #   @api public
      #   @return [String] what Erik did
      #   @example
      #     project.description # => "top contributor (1,900+ commits)..."
      attribute :description
    end
  end
end
