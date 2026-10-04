# frozen_string_literal: true

require_relative "../json_parsing"
require_relative "../dependency"
require_relative "../finger"
require_relative "../home"
require_relative "../name_change"
require_relative "../whoami"

module Sferik
  module API
    # The endpoints about Erik: the bio, the comic, contact details, and the name change
    # @api public
    module ProfileEndpoints
      include JSONParsing

      # Returns the profile and the home page's modules
      #
      # The home page builds itself from these.
      #
      # @api public
      # @return [Home]
      # @example
      #   Sferik.home.profile.tagline
      def home
        Home.new(parse_json(get("")))
      end

      # Returns the bio: paragraphs of HTML
      #
      # @api public
      # @return [Whoami]
      # @example
      #   Sferik.whoami.blocks.map(&:html)
      def whoami
        Whoami.new(parse_json(get("/whoami")))
      end

      # Returns the xkcd comic on the home page: xkcd 2347, adapted
      #
      # @api public
      # @return [Dependency]
      # @example
      #   Sferik.dependency.figure.alt
      def dependency
        Dependency.new(parse_json(get("/dependency")))
      end

      # Returns contact details and profiles elsewhere
      #
      # @api public
      # @return [Finger]
      # @example
      #   Sferik.finger.profiles.map(&:url)
      def finger
        Finger.new(parse_json(get("/finger")))
      end

      # Returns the name change, from Erik Michaels-Ober to Erik Berlin, as a git commit
      #
      # @api public
      # @return [NameChange]
      # @example
      #   Sferik.name_change.year # => 2017
      def name_change
        NameChange.new(parse_json(get("/name")))
      end
    end
  end
end
