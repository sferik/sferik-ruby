# frozen_string_literal: true

require_relative "../resource"
require_relative "location"
require_relative "profile"

module Sferik
  class Resume < Resource
    # Name, contact details, and summary, as returned by {Resume#basics}
    # @api public
    class Basics < Resource
      # @!method name
      #   The name
      #   @api public
      #   @return [String] the name
      #   @example
      #     basics.name # => "Erik Berlin"
      attribute :name

      # @!method label
      #   The title
      #   @api public
      #   @return [String] the title
      #   @example
      #     basics.label # => "Software Engineer"
      attribute :label

      # @!method former_name
      #   The name before 2017 (an addition to JSON Resume)
      #   @api public
      #   @return [String] the name before 2017 (an addition to JSON Resume)
      #   @example
      #     basics.former_name # => "Erik Michaels-Ober"
      attribute :former_name

      # @!method email
      #   The email address
      #   @api public
      #   @return [String] the email address
      #   @example
      #     basics.email # => "sferik@gmail.com"
      attribute :email

      # @!method url
      #   The site
      #   @api public
      #   @return [String] the site
      #   @example
      #     basics.url # => "https://sferik.net"
      attribute :url

      # @!method summary
      #   Paragraphs separated by blank lines, with **bold** and *italic*
      #   @api public
      #   @return [String] paragraphs separated by blank lines, with **bold** and *italic*
      #   @example
      #     basics.summary # => "Entrepreneur, engineer, and manager..."
      attribute :summary

      # @!method location
      #   Where Erik lives
      #   @api public
      #   @return [Location] where Erik lives
      #   @example
      #     basics.location # => #<Sferik::Resume::Location ...>
      attribute :location, "location", type: Location

      # @!method profiles
      #   Profiles elsewhere
      #   @api public
      #   @return [Array<Profile>] profiles elsewhere
      #   @example
      #     basics.profiles # => [#<Sferik::Resume::Profile ...>, ...]
      list :profiles, "profiles", type: Profile
    end
  end
end
