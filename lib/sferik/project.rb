# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A project, as returned in {Projects#projects}
  # @api public
  class Project < Resource
    # @!method name
    #   The project's name
    #   @api public
    #   @return [String] the project's name
    #   @example
    #     project.name # => "multi_json"
    attribute :name

    # @!method description
    #   What it is
    #   @api public
    #   @return [String] what it is
    #   @example
    #     project.description # => "One interface to every Ruby JSON library."
    attribute :description

    # @!method downloads
    #   Its RubyGems downloads, or nil if it isn't a gem
    #   @api public
    #   @return [Integer, nil] its RubyGems downloads, or nil if it isn't a gem
    #   @example
    #     project.downloads # => 1_170_000_000
    attribute :downloads

    # @!method stars
    #   Its GitHub stars, or nil if it isn't on GitHub
    #   @api public
    #   @return [Integer, nil] its GitHub stars, or nil if it isn't on GitHub
    #   @example
    #     project.stars # => 27
    attribute :stars

    # @!method url
    #   Its home page
    #   @api public
    #   @return [String] its home page
    #   @example
    #     project.url # => "https://github.com/sferik/multi_json"
    attribute :url
  end
end
