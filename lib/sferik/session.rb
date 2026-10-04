# frozen_string_literal: true

require_relative "resource"

module Sferik
  # A reader's terminal, one per browser tab, as returned in {Who#users}
  # @api public
  class Session < Resource
    # @!method tty
    #   The terminal's name
    #   @api public
    #   @return [String] the terminal's name
    #   @example
    #     session.tty # => "ttys001"
    attribute :tty

    # @!method page
    #   The page the tab is on
    #   @api public
    #   @return [String] the page the tab is on
    #   @example
    #     session.page # => "/talks"
    attribute :page

    # @!method login
    #   When the tab opened
    #   @api public
    #   @return [Time] when the tab opened
    #   @example
    #     session.login # => 2026-10-06 12:00:00 UTC
    timestamp :login, Time

    # @!method idle
    #   The seconds since the tab last checked in
    #   @api public
    #   @return [Integer] the seconds since the tab last checked in
    #   @example
    #     session.idle # => 42
    attribute :idle
  end
end
