# frozen_string_literal: true

require_relative "resource"
require_relative "day"
require_relative "push"

module Sferik
  # A year of GitHub contributions, as returned by {API::CodeEndpoints#contributions}
  # @api public
  class Contributions < Resource
    # @!method total
    #   The contributions in the last year
    #   @api public
    #   @return [Integer] the contributions in the last year
    #   @example
    #     contributions.total # => 5242
    attribute :total

    # @!method longest_streak
    #   The longest run of days with contributions, in days
    #   @api public
    #   @return [Integer] the longest run of days with contributions, in days
    #   @example
    #     contributions.longest_streak # => 30
    attribute :longest_streak

    # @!method days
    #   One entry per day, oldest first
    #   @api public
    #   @return [Array<Day>] one entry per day, oldest first
    #   @example
    #     contributions.days # => [#<Sferik::Day ...>, ...]
    list :days, "contributions", type: Day

    # @!method since
    #   The year the GitHub account was created
    #   @api public
    #   @return [Integer] the year the GitHub account was created
    #   @example
    #     contributions.since # => 2008
    attribute :since

    # @!method last_push
    #   The latest public push, or nil if none is recent
    #   @api public
    #   @return [Push, nil] the latest public push, or nil if none is recent
    #   @example
    #     contributions.last_push # => #<Sferik::Push ...>
    attribute :last_push, "lastPush", type: Push

    # @!method live?
    #   Whether the numbers are what GitHub says now
    #
    #   They aren't when they're the snapshot, which the site falls back to, or the last that were fetched, more than
    #   two hours ago, which it goes on with when it can't fetch them again: {#as_of} says when they're from.
    #
    #   @api public
    #   @return [Boolean] false when the numbers are a snapshot, or were last fetched more than two hours ago
    #   @example
    #     contributions.live? # => true
    predicate :live

    # @!method as_of
    #   When the numbers are from
    #
    #   That's when they were fetched, or the last day of the snapshot, if they're that.
    #
    #   @api public
    #   @return [Time] when the numbers are from
    #   @example
    #     contributions.as_of # => 2026-10-08 01:15:02 UTC
    timestamp :as_of, Time

    # @!method command
    #   The shell command the home page shows it as
    #   @api public
    #   @return [String] the shell command the home page shows it as
    #   @example
    #     contributions.command # => "git log --author=sferik --since=1.year --graph"
    attribute :command

    inspect_with :total, :longest_streak, :since
  end
end
