# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A conference talk, as returned in {Talks#talks}
  # @api public
  class Talk < Resource
    # @!method title
    #   The talk's title
    #   @api public
    #   @return [String] the talk's title
    #   @example
    #     talk.title # => "Writing Fast Ruby"
    attribute :title

    # @!method event
    #   The conference
    #   @api public
    #   @return [String] the conference
    #   @example
    #     talk.event # => "Baruco"
    attribute :event

    # @!method date
    #   When it was, to the month: the first day of that month
    #   @api public
    #   @return [Date] the first day of the month it was in
    #   @example
    #     talk.date # => #<Date: 2014-09-01>
    timestamp :date, PartialDate

    # @!method location
    #   Where the conference was
    #   @api public
    #   @return [String] where the conference was
    #   @example
    #     talk.location # => "Barcelona"
    attribute :location

    # @!method slides
    #   The slides, if they're online
    #   @api public
    #   @return [String, nil] the slides, if they're online
    #   @example
    #     talk.slides # => "https://speakerdeck.com/sferik/writing-fast-ruby"
    attribute :slides

    # @!method video
    #   The video, if there is one
    #   @api public
    #   @return [String, nil] the video, if there is one
    #   @example
    #     talk.video # => "https://www.youtube.com/watch?v=fGFM_UrSp70"
    attribute :video

    # @!method link
    #   The talk's page on the event's site, if it has one
    #   @api public
    #   @return [String, nil] the talk's page on the event's site, if it has one
    #   @example
    #     talk.link # => "https://schedule.sxsw.com/2015/events/event_IAP35000"
    attribute :link

    # @!method featured?
    #   Whether the home page shows it
    #   @api public
    #   @return [Boolean] whether the home page shows it
    #   @example
    #     talk.featured? # => true
    predicate :featured
  end
end
