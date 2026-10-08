# frozen_string_literal: true

require_relative "resource"
require_relative "collection"
require_relative "talk"
require_relative "place"
require_relative "podcast"

module Sferik
  # Conference talks and podcasts, as returned by {API::TalkEndpoints#talks}
  #
  # It's Enumerable over its {#talks}, so `Sferik.talks.first` is the newest, and `Sferik.talks.map(&:title)` lists
  # them all. It also has what an Array adds to that: {#size}, {#length}, {#empty?}, {#last}, and {#[]}.
  #
  # @api public
  class Talks < Resource
    include Enumerable
    include Collection

    # ActiveSupport's Enumerable#as_json would make a list of them; keep the JSON it came from, as for any resource
    define_method(:as_json, Resource.instance_method(:as_json))

    # @!method talks
    #   The talks, newest first
    #   @api public
    #   @return [Array<Talk>] the talks, newest first
    #   @example
    #     talks.talks # => [#<Sferik::Talk ...>, ...]
    list :talks, "talks", type: Talk

    # @!method places
    #   Where each talk's location is, by the name {Talk#location} gives it
    #   @api public
    #   @return [Hash{String => Place}] where each talk's location is, by name
    #   @example
    #     talks.places["Barcelona"] # => #<Sferik::Place lat=41.39 lon=2.17 country="Spain">
    dictionary :places, type: Place

    # @!method podcasts
    #   The podcast appearances
    #   @api public
    #   @return [Array<Podcast>] the podcast appearances
    #   @example
    #     talks.podcasts # => [#<Sferik::Podcast ...>, ...]
    list :podcasts, "podcasts", type: Podcast

    # @!method speaker_deck
    #   Where the slides are
    #   @api public
    #   @return [String] where the slides are
    #   @example
    #     talks.speaker_deck # => "https://speakerdeck.com/sferik"
    attribute :speaker_deck

    # @!method command
    #   The shell command the home page shows the newest talks as
    #   @api public
    #   @return [String] the shell command the home page shows the newest talks as
    #   @example
    #     talks.command # => "ls -t ~/talks | head -6"
    attribute :command

    inspect_with :size, :speaker_deck

    # Yield each talk, newest first
    #
    # @api public
    # @yieldparam talk [Talk] a talk
    # @return [self, Enumerator<Talk>] the talks themselves, or an Enumerator without a block
    # @example
    #   Sferik.talks.each { |talk| puts talk.title }
    def each(&block)
      return to_enum { size } unless block

      talks.each(&block)
      self
    end
  end
end
