# frozen_string_literal: true

require_relative "resource"

module Sferik
  # An image, and what it is in words, as returned by {Dependency#figure}
  # @api public
  class Figure < Resource
    # @!method type
    #   "figure"
    #   @api public
    #   @return [String] "figure"
    #   @example
    #     figure.type # => "figure"
    attribute :type

    # @!method href
    #   Where the image is from
    #   @api public
    #   @return [String] where the image is from
    #   @example
    #     figure.href # => "https://xkcd.com/2347/"
    attribute :href

    # @!method src
    #   The image's path
    #   @api public
    #   @return [String] the image's path
    #   @example
    #     figure.src # => "/img/dependency.webp"
    attribute :src

    # @!method srcset
    #   The image's paths by pixel density
    #   @api public
    #   @return [String] the image's paths by pixel density
    #   @example
    #     figure.srcset # => "/img/dependency.webp 1x, /img/dependency-2x.webp 2x"
    attribute :srcset

    # @!method width
    #   The image's width in pixels
    #   @api public
    #   @return [Integer] the image's width in pixels
    #   @example
    #     figure.width # => 385
    attribute :width

    # @!method height
    #   The image's height in pixels
    #   @api public
    #   @return [Integer] the image's height in pixels
    #   @example
    #     figure.height # => 489
    attribute :height

    # @!method alt
    #   What the image shows, in words
    #   @api public
    #   @return [String] what the image shows, in words
    #   @example
    #     figure.alt # => "A tall, precarious tower of blocks..."
    attribute :alt

    # @!method title
    #   The image's title text
    #   @api public
    #   @return [String] the image's title text
    #   @example
    #     figure.title # => "Someday ImageMagick will finally break for good..."
    attribute :title

    # @!method caption
    #   The image's caption, as HTML
    #   @api public
    #   @return [String] the image's caption, as HTML
    #   @example
    #     figure.caption # => "Adapted from ..."
    attribute :caption

    inspect_with :href, :src
  end
end
