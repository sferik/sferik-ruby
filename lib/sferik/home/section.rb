# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Home < Resource
    # One of the home page's modules, as returned in {Home#modules}
    # @api public
    class Section < Resource
      # @!method id
      #   The module's name
      #   @api public
      #   @return [String] the module's name
      #   @example
      #     section.id # => "whoami"
      attribute :id

      # @!method url
      #   Its path, which {Client#get} takes
      #   @api public
      #   @return [String] its path, which {Client#get} takes
      #   @example
      #     section.url # => "/whoami"
      attribute :url
    end
  end
end
