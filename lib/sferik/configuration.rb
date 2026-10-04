# frozen_string_literal: true

require_relative "version"

module Sferik
  # The global configuration, which {Sferik.client} is built from
  #
  # @api public
  # @example Configure the library
  #   Sferik.configure do |config|
  #     config.host = "http://localhost:3745"
  #     config.read_timeout = 30
  #   end
  module Configuration
    # The settings, and what each is until it is assigned
    DEFAULTS = {
      host: "https://sferik.net",
      user_agent: "sferik/#{VERSION} (#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}; +https://rubygems.org/gems/sferik)".freeze,
      open_timeout: 5,
      read_timeout: 10,
      write_timeout: 10,
      max_redirects: 10
    }.freeze
    private_constant :DEFAULTS

    # @!attribute host
    #   The host for API requests, including the scheme
    #   @api public
    #   @return [String] the host (defaults to "https://sferik.net")
    #   @example
    #     Sferik.host = "http://localhost:3745"
    # @!attribute user_agent
    #   The 'User-Agent' HTTP header sent with requests
    #   @api public
    #   @return [String] the user agent
    #   @example
    #     Sferik.user_agent = "my-app/1.0"
    # @!attribute open_timeout
    #   The seconds to wait for a connection to open
    #   @api public
    #   @return [Numeric] the timeout, which must be positive and finite (defaults to 5)
    #   @example
    #     Sferik.open_timeout = 2
    # @!attribute read_timeout
    #   The seconds to wait for a response
    #
    #   Net::HTTP sends a request that times out once more, so a response that never comes takes twice this long to fail.
    #
    #   @api public
    #   @return [Numeric] the timeout, which must be positive and finite (defaults to 10)
    #   @example
    #     Sferik.read_timeout = 30
    # @!attribute write_timeout
    #   The seconds to wait for a request to be sent
    #
    #   It matters for a POST, whose body is the message of {API::SiteEndpoints#write}. Net::HTTP has no such timeout on Windows.
    #
    #   @api public
    #   @return [Numeric] the timeout, which must be positive and finite (defaults to 10)
    #   @example
    #     Sferik.write_timeout = 30
    # @!attribute max_redirects
    #   The most redirects to follow for one request
    #   @api public
    #   @return [Integer] the limit, which must not be negative (defaults to 10)
    #   @example
    #     Sferik.max_redirects = 0 # don't follow any
    DEFAULTS.each_key { |setting| attr_accessor setting } # one at a time: YARD can't read the names of a splat

    # Start what this module extends at the defaults
    #
    # @api private
    # @param base [Module] the module being extended
    # @return [Module] the module, reset
    # @example
    #   Sferik.extend(Sferik::Configuration)
    def self.extended(base)
      base.reset
    end

    # Change the configuration in a block
    #
    # @api public
    # @yield [config] the configuration
    # @return [self]
    # @raise [ArgumentError] if no block is given
    # @example
    #   Sferik.configure { |config| config.host = "http://localhost:3745" }
    def configure
      raise ArgumentError, "configure must be given a block" unless block_given?

      yield self
      self
    end

    # Every setting, as the options of {Client#initialize}
    #
    # @api public
    # @return [Hash{Symbol => Object}] the settings
    # @example
    #   Sferik.options # => {host: "https://sferik.net", ...}
    def options
      DEFAULTS.to_h { |setting, _| [setting, public_send(setting)] }
    end

    # Put every setting back to its default
    #
    # @api public
    # @return [self]
    # @example
    #   Sferik.reset
    def reset
      DEFAULTS.each { |setting, value| instance_variable_set(:"@#{setting}", value) }
      self
    end
  end
end
