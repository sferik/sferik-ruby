# frozen_string_literal: true

require_relative "../json_parsing"
require_relative "../contributions"
require_relative "../projects"

module Sferik
  module API
    # The endpoints about code: GitHub contributions, and projects with their downloads and stars
    # @api public
    module CodeEndpoints
      include JSONParsing

      # Returns a year of GitHub contributions, the longest streak, and the latest push
      #
      # The server fetches these from GitHub and caches them; if GitHub can't be reached, the response is a snapshot,
      # and {Contributions#live?} is false.
      #
      # @api public
      # @return [Contributions]
      # @example
      #   Sferik.contributions.days.max_by(&:count).date
      def contributions
        Contributions.new(parse_json(get("/contributions")))
      end

      # Returns projects with their RubyGems downloads and GitHub stars
      #
      # Most downloaded first, except that related projects are listed together.
      #
      # @api public
      # @return [Projects]
      # @example
      #   Sferik.projects.total_downloads # => 5_460_234_129
      def projects
        Projects.new(parse_json(get("/src")))
      end
    end
  end
end
