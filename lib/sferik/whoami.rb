# frozen_string_literal: true

require_relative "resource"
require_relative "block"

module Sferik
  # The bio, as returned by {API::ProfileEndpoints#whoami}
  # @api public
  class Whoami < Resource
    # @!method command
    #   The shell command the home page shows it as
    #   @api public
    #   @return [String] the shell command the home page shows it as
    #   @example
    #     whoami.command # => "whoami"
    attribute :command

    # @!method blocks
    #   The paragraphs, in order
    #   @api public
    #   @return [Array<Block>] the paragraphs, in order
    #   @example
    #     whoami.blocks # => [#<Sferik::Block ...>, ...]
    list :blocks, "blocks", type: Block

    # @!method multi_downloads
    #   The combined RubyGems downloads of multi_json and multi_xml
    #   @api public
    #   @return [Integer] the combined RubyGems downloads of multi_json and multi_xml
    #   @example
    #     whoami.multi_downloads # => 1_776_825_140
    attribute :multi_downloads

    inspect_with :command, :multi_downloads
  end
end
