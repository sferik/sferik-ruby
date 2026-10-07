# frozen_string_literal: true

require_relative "../json_parsing"
require_relative "../talks"

module Sferik
  module API
    # The endpoints about speaking
    # @api public
    module TalkEndpoints
      include JSONParsing

      # Returns conference talks, newest first, and podcast appearances
      #
      # The talks are Enumerable: `Sferik.talks.first` is the newest. {Talks#places} is where each one's location is.
      #
      # @api public
      # @return [Talks]
      # @example
      #   Sferik.talks.select(&:video).map(&:title)
      def talks
        Talks.new(parse_json(get("/talks")))
      end

      # Returns the talks as an Atom feed, newest first
      #
      # @api public
      # @return [String] the feed, as XML
      # @example
      #   File.write("talks.atom", Sferik.talks_feed)
      def talks_feed
        get("/talks.atom", accept: "application/atom+xml")
      end

      # Returns podcast appearances
      #
      # They come with the talks too, as {Talks#podcasts}: this asks for them alone.
      #
      # @api public
      # @return [Array<Podcast>]
      # @example
      #   Sferik.podcasts.first.show # => "Ruby Rogues, episode 248"
      def podcasts
        Talks.new(parse_json(get("/podcasts"))).podcasts # the response is the talks' with only the podcasts
      end
    end
  end
end
