# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A podcast appearance, as returned in {Talks#podcasts}
  # @api public
  class Podcast < Resource
    # @!method title
    #   The episode's title
    #   @api public
    #   @return [String] the episode's title
    #   @example
    #     podcast.title # => "The Crystal Programming Language"
    attribute :title

    # @!method show
    #   The podcast
    #   @api public
    #   @return [String] the podcast
    #   @example
    #     podcast.show # => "Ruby Rogues, episode 248"
    attribute :show

    # @!method date
    #   When it was, to the month: the first day of that month
    #   @api public
    #   @return [Date] the first day of the month it was in
    #   @example
    #     podcast.date # => #<Date: 2016-02-01>
    timestamp :date, PartialDate

    # @!method url
    #   The episode
    #   @api public
    #   @return [String] the episode
    #   @example
    #     podcast.url # => "https://..."
    attribute :url
  end
end
