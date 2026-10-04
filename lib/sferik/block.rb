# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A paragraph of the bio, as returned in {Whoami#blocks}
  # @api public
  class Block < Resource
    # @!method type
    #   The kind of block: "p" for a paragraph
    #   @api public
    #   @return [String] the kind of block: "p" for a paragraph
    #   @example
    #     block.type # => "p"
    attribute :type

    # @!method html
    #   The paragraph, as HTML
    #   @api public
    #   @return [String] the paragraph, as HTML
    #   @example
    #     block.html # => "I've spent nearly two decades..."
    attribute :html
  end
end
