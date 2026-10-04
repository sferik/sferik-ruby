# frozen_string_literal: true

require_relative "resource"
require_relative "collection"
require_relative "project"

module Sferik
  # Projects with their downloads and stars, as returned by {API::CodeEndpoints#projects}
  #
  # It's Enumerable over its {#projects}, so `Sferik.projects.first` is the most downloaded, and
  # `Sferik.projects.map(&:name)` lists them all. It also has what an Array adds to that: {#size}, {#length},
  # {#empty?}, {#last}, and {#[]}.
  #
  # @api public
  class Projects < Resource
    include Enumerable
    include Collection

    # Enumerable's #to_h would make a Hash of the projects; keep the readers, as for any resource
    define_method(:to_h, Resource.instance_method(:to_h))

    # ActiveSupport's Enumerable#as_json would make a list of them; keep the JSON it came from, as for any resource
    define_method(:as_json, Resource.instance_method(:as_json))

    # @!method projects
    #   The projects, most downloaded first, with related ones together
    #   @api public
    #   @return [Array<Project>] the projects, most downloaded first, with related ones together
    #   @example
    #     projects.projects # => [#<Sferik::Project ...>, ...]
    list :projects, "projects", type: Project

    # The RubyGems downloads of every gem @sferik owns, not only those listed
    #
    # @api public
    # @return [Integer, nil] the RubyGems downloads of every gem @sferik owns, not only those listed
    # @example
    #   projects.total_downloads # => 5_460_234_129
    def total_downloads
      total["downloads"]
    end
    record :total_downloads

    # The number of gems @sferik owns
    #
    # @api public
    # @return [Integer, nil] the number of gems @sferik owns
    # @example
    #   projects.total_gems # => 65
    def total_gems
      total["gems"]
    end
    record :total_gems

    # The GitHub stars of the projects listed
    #
    # @api public
    # @return [Integer, nil] the GitHub stars of the projects listed
    # @example
    #   projects.total_stars # => 38_000
    def total_stars
      total["stars"]
    end
    record :total_stars

    # @!method more
    #   Where to find the rest
    #   @api public
    #   @return [String] where to find the rest
    #   @example
    #     projects.more # => "https://github.com/sferik"
    attribute :more

    # @!method live?
    #   False when RubyGems or GitHub couldn't be reached and the numbers are a snapshot
    #   @api public
    #   @return [Boolean] false when RubyGems or GitHub couldn't be reached and the numbers are a snapshot
    #   @example
    #     projects.live? # => true
    predicate :live

    # @!method as_of
    #   When the downloads are from
    #
    #   That's when they were fetched, or the day of the snapshot when {#live?} is false.
    #
    #   @api public
    #   @return [Time] when the downloads are from
    #   @example
    #     projects.as_of # => 2026-10-08 01:15:02 UTC
    timestamp :as_of, Time

    # @!method command
    #   The shell command the home page shows it as
    #   @api public
    #   @return [String] the shell command the home page shows it as
    #   @example
    #     projects.command # => "ls -lS ~/src"
    attribute :command

    inspect_with :size, :total_downloads, :total_stars

    # Yield each project, most downloaded first (related projects together)
    #
    # @api public
    # @yieldparam project [Project] a project
    # @return [self, Enumerator<Project>] the projects themselves, or an Enumerator without a block
    # @example
    #   Sferik.projects.each { |project| puts project.name }
    def each(&block)
      return to_enum { size } unless block

      projects.each(&block)
      self
    end

    private

    # The totals, which are empty when the response has none, and are checked when the projects are built
    prepare(:total) do
      value = attributes["total"] || NONE
      raise InvalidResponse, "#{self.class}#total: expected a JSON object, got #{value.class}" unless value.instance_of?(Hash)

      value
    end

    # The totals, which are empty when the response has none
    #
    # @api private
    # @return [Hash{String => Object}] the totals
    def total
      prepared(:total)
    end
  end
end
