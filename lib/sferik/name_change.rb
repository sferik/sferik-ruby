# frozen_string_literal: true

require_relative "resource"

module Sferik
  # The name change, as a git commit, as returned by {API::ProfileEndpoints#name_change}
  # @api public
  class NameChange < Resource
    # @!method subject
    #   The commit's subject
    #   @api public
    #   @return [String] the commit's subject
    #   @example
    #     name_change.subject # => "Rename Erik Michaels-Ober to Erik Berlin"
    attribute :subject

    # @!method year
    #   The year of the change
    #   @api public
    #   @return [Integer] the year of the change
    #   @example
    #     name_change.year # => 2017
    attribute :year

    # @!method commit
    #   The commit's abbreviated hash
    #   @api public
    #   @return [String] the commit's abbreviated hash
    #   @example
    #     name_change.commit # => "8c0d698"
    attribute :commit

    # @!method notes
    #   More about it, as HTML
    #   @api public
    #   @return [Array<String>] more about it, as HTML
    #   @example
    #     name_change.notes # => ["..."]
    list :notes

    # @!method command
    #   The shell command the home page shows it as
    #   @api public
    #   @return [String] the shell command the home page shows it as
    #   @example
    #     name_change.command # => "git log --follow --oneline -- name"
    attribute :command
  end
end
