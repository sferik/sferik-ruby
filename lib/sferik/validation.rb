# frozen_string_literal: true

require "uri"

module Sferik
  # Checks the options of a client and the arguments of its requests, for {Client}, and the attributes of a {Resource}
  #
  # A wrong one raises ArgumentError where it's given, rather than an error in the middle of a request.
  #
  # @api private
  module Validation
    private

    # Check the type of an option, an argument, or a resource's attributes
    #
    # A wrong one fails here rather than in the middle of a request.
    #
    # @api private
    # @param option [Symbol] the option's name, or the argument's: :path, :body, :accept, :token, :page, :tty, :attributes, or :key
    # @param value [Object] its value
    # @param type [Class] the class its value should be of
    # @return [Object] the value
    # @raise [ArgumentError] if the value isn't of that class
    def check(option, value, type)
      return value if value.is_a?(type)

      raise ArgumentError, "#{option} must be #{type}, not #{value.inspect}"
    end

    # Check that a host is an http or https URL, and no more than one
    #
    # One without a scheme, like "localhost:3745", fails here rather than in the middle of a request. So does one
    # with a query or a fragment, which a path added to it would be part of, and one with credentials, which are
    # never sent.
    #
    # @api private
    # @param value [String] the host
    # @return [String] the host
    # @raise [ArgumentError] if the host isn't an http or https URL, or has credentials, a query, or a fragment
    def http_url(value)
      uri = URI.parse(value)
      raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
      return value if [uri.userinfo, uri.query, uri.fragment].none?

      raise ArgumentError, "host must have no credentials, query, or fragment, not #{value.inspect}"
    rescue URI::InvalidURIError
      raise ArgumentError, "host must be an http or https URL, not #{value.inspect}"
    end

    # Check that an option is true or false
    #
    # @api private
    # @param option [Symbol] the option's name
    # @param value [Object] its value
    # @return [Boolean] the value
    # @raise [ArgumentError] if the value is neither true nor false
    def boolean(option, value)
      return value if [true, false].include?(value)

      raise ArgumentError, "#{option} must be true or false, not #{value.inspect}"
    end

    # Check that the value of a header is on one line
    #
    # Net::HTTP fails in the middle of a request with one that has a carriage return or a line feed.
    #
    # @api private
    # @param option [Symbol] the option's name, or :accept
    # @param value [String] its value
    # @return [String] the value
    # @raise [ArgumentError] if the value has a line break
    def one_line(option, value)
      return value unless value.match?(/[\r\n]/)

      raise ArgumentError, "#{option} must be on one line, not #{value.inspect}"
    end

    # Check that a timeout is a number of seconds, positive and finite
    #
    # @api private
    # @param option [Symbol] the option's name
    # @param value [Object] its value
    # @return [Numeric] the value
    # @raise [ArgumentError] if the value isn't Numeric, or isn't positive and finite
    def seconds(option, value)
      positive(option, check(option, value, Numeric))
    end

    # Check that a timeout is positive and finite
    #
    # Net::HTTP waits forever with one of 0, or an infinite one, and fails in the middle of a request with a negative
    # one. A complex number is Numeric, but is neither positive nor negative.
    #
    # @api private
    # @param option [Symbol] the option's name
    # @param value [Numeric] its value
    # @return [Numeric] the value
    # @raise [ArgumentError] if the value isn't a real number, isn't finite, or isn't positive
    def positive(option, value)
      return value if value.real? && value.finite? && value.positive?

      raise ArgumentError, "#{option} must be positive and finite, not #{value}"
    end

    # Check that a limit isn't negative
    #
    # @api private
    # @param option [Symbol] the option's name
    # @param value [Integer] its value
    # @return [Integer] the value
    # @raise [ArgumentError] if the value is negative
    def not_negative(option, value)
      return value unless value.negative?

      raise ArgumentError, "#{option} must be 0 or more, not #{value}"
    end
  end
  private_constant :Validation
end
