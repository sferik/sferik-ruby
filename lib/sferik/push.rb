# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A push to GitHub, as returned by {Contributions#last_push}
  # @api public
  class Push < Resource
    # @!method repo
    #   The repository
    #   @api public
    #   @return [String] the repository
    #   @example
    #     push.repo # => "sferik/x-ruby"
    attribute :repo

    # @!method sha
    #   The commit at the head of the push
    #   @api public
    #   @return [String] the commit at the head of the push
    #   @example
    #     push.sha # => "abc1234def5678"
    attribute :sha

    # @!method at
    #   When it was pushed
    #   @api public
    #   @return [Time] when it was pushed
    #   @example
    #     push.at # => 2026-10-01 12:00:00 UTC
    timestamp :at, Time
  end
end
