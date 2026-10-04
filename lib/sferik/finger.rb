# frozen_string_literal: true

require_relative "resource"
require_relative "social_profile"

module Sferik
  # Contact details and profiles, as returned by {API::ProfileEndpoints#finger}
  # @api public
  class Finger < Resource
    # @!method name
    #   The full name
    #   @api public
    #   @return [String] the full name
    #   @example
    #     finger.name # => "Erik Berlin"
    attribute :name

    # @!method login
    #   The handle
    #   @api public
    #   @return [String] the handle
    #   @example
    #     finger.login # => "sferik"
    attribute :login

    # @!method mail
    #   The email address
    #   @api public
    #   @return [String] the email address
    #   @example
    #     finger.mail # => "sferik@gmail.com"
    attribute :mail

    # @!method directory
    #   The home directory, in the site's shell
    #   @api public
    #   @return [String] the home directory, in the site's shell
    #   @example
    #     finger.directory # => "/Users/sferik"
    attribute :directory

    # @!method shell
    #   The login shell, in the site's shell
    #   @api public
    #   @return [String] the login shell, in the site's shell
    #   @example
    #     finger.shell # => "/opt/homebrew/bin/fish"
    attribute :shell

    # @!method plan
    #   The .plan
    #   @api public
    #   @return [String] the .plan
    #   @example
    #     finger.plan # => "..."
    attribute :plan

    # @!method profiles
    #   Profiles elsewhere
    #   @api public
    #   @return [Array<SocialProfile>] profiles elsewhere
    #   @example
    #     finger.profiles # => [#<Sferik::SocialProfile ...>, ...]
    list :profiles, "profiles", type: SocialProfile

    # @!method command
    #   The shell command the home page shows it as
    #   @api public
    #   @return [String] the shell command the home page shows it as
    #   @example
    #     finger.command # => "finger sferik"
    attribute :command
  end
end
