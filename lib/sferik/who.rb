# frozen_string_literal: true

require_relative "resource"
require_relative "collection"
require_relative "session"

module Sferik
  # Everyone reading the site right now, as returned by {API::SiteEndpoints#who} and {API::SiteEndpoints#check_in}
  #
  # It's Enumerable over its {#users}, so `Sferik.who.map(&:page)` lists the pages being read. It also has what an
  # Array adds to that: {#size}, {#length}, {#empty?}, {#last}, and {#[]}.
  #
  # @api public
  class Who < Resource
    include Enumerable
    include Collection

    # ActiveSupport's Enumerable#as_json would make a list of them; keep the JSON it came from, as for any resource
    define_method(:as_json, Resource.instance_method(:as_json))

    # @!method users
    #   The terminals logged in: one per browser tab
    #   @api public
    #   @return [Array<Session>] the terminals logged in: one per browser tab
    #   @example
    #     who.users # => [#<Sferik::Session tty="ttys001" page="/" login=2026-10-06 12:00:00 UTC>]
    list :users, "users", type: Session

    # @!method you
    #   The terminal that checked in, from {API::SiteEndpoints#check_in}
    #   @api public
    #   @return [String, nil] the terminal's name: nil when every terminal is taken, or when nobody checked in
    #   @example
    #     Sferik.check_in(token).you # => "ttys001"
    attribute :you

    inspect_with :size

    # Yield each terminal
    #
    # @api public
    # @yieldparam session [Session] a terminal
    # @return [self, Enumerator<Session>] the terminals themselves, or an Enumerator without a block
    # @example
    #   Sferik.who.each { |session| puts session.tty }
    def each(&block)
      return to_enum { size } unless block

      users.each(&block)
      self
    end
  end
end
