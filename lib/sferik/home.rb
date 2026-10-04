# frozen_string_literal: true

require_relative "resource"
require_relative "home/pages"
require_relative "home/profile"
require_relative "home/section"

module Sferik
  # The profile and the home page's modules, as returned by {API::ProfileEndpoints#home}
  # @api public
  class Home < Resource
    # @!method profile
    #   Who the site is about
    #   @api public
    #   @return [Profile] who the site is about
    #   @example
    #     home.profile # => #<Sferik::Home::Profile ...>
    attribute :profile, "profile", type: Profile

    # @!method modules
    #   The home page's modules, in order
    #   @api public
    #   @return [Array<Section>] the home page's modules, in order
    #   @example
    #     home.modules # => [#<Sferik::Home::Section id="whoami" ...>, ...]
    list :modules, "modules", type: Section

    # @!method pages
    #   The paths of the other pages
    #   @api public
    #   @return [Pages] the paths of the other pages
    #   @example
    #     home.pages # => #<Sferik::Home::Pages ...>
    attribute :pages, "pages", type: Pages

    inspect_with :profile
  end
end
