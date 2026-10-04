# frozen_string_literal: true

require_relative "resource"
require_relative "figure"

module Sferik
  # The xkcd comic on the home page, as returned by {API::ProfileEndpoints#dependency}
  # @api public
  class Dependency < Resource
    # @!method command
    #   The shell command the home page shows it as
    #   @api public
    #   @return [String] the shell command the home page shows it as
    #   @example
    #     dependency.command # => "imgcat ~/dependency.webp"
    attribute :command

    # @!method figure
    #   The comic, and what it shows in words
    #   @api public
    #   @return [Figure] the comic, and what it shows in words
    #   @example
    #     dependency.figure # => #<Sferik::Figure href="https://xkcd.com/2347/" src="/img/dependency.webp">
    attribute :figure, "figure", type: Figure
  end
end
