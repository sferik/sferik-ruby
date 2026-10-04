# frozen_string_literal: true

require_relative "errors"
require_relative "validation"

module Sferik
  # Checks the attributes of a resource, freezes the values of a response, and wraps them in resources, for {Resource}
  # @api private
  module Wrapping
    include Validation

    private

    # Wrap a value in a resource class
    #
    # @api private
    # @param value [Object] the value
    # @param type [Class, nil] the resource class, or nil to leave the value as it is
    # @return [Object] the value, wrapped
    # @raise [InvalidResponse] if the value isn't a JSON object
    def wrap(value, type)
      (type && value) ? build(type, value) : value
    end

    # Wrap each value of a list in a resource class
    #
    # @api private
    # @param name [Symbol] the reader of the list
    # @param list [Object] the list
    # @param type [Class, nil] the resource class, or nil to leave the values as they are
    # @return [Array<Object>] the values, wrapped and frozen
    # @raise [InvalidResponse] if the list isn't a JSON array, or one in it isn't a JSON object
    def wrap_list(name, list, type)
      raise InvalidResponse, "#{self.class}##{name}: expected a JSON array, got #{list.class}" unless list.instance_of?(Array)

      type ? list.map { |item| build(type, item) }.freeze : list
    end

    # Wrap each value of a dictionary in a resource class
    #
    # @api private
    # @param name [Symbol] the reader of the dictionary
    # @param dictionary [Object] the dictionary
    # @param type [Class] the resource class
    # @return [Hash{String => Resource}] the values, wrapped and frozen
    # @raise [InvalidResponse] if the dictionary isn't a JSON object, or one in it isn't
    def wrap_dictionary(name, dictionary, type)
      raise InvalidResponse, "#{self.class}##{name}: expected a JSON object, got #{dictionary.class}" unless dictionary.instance_of?(Hash)

      dictionary.transform_values { |item| build(type, item) }.freeze
    end

    # Parse an ISO 8601 date or time
    #
    # @api private
    # @param name [Symbol] the reader of the date or time
    # @param value [Object] the value
    # @param parser [#iso8601] Time, Date, or PartialDate for a date that may be given to the year or month
    # @return [Time, Date, nil] the date or time, frozen, or nil if the response has none
    # @raise [InvalidResponse] if the value isn't an ISO 8601 date or time
    def wrap_timestamp(name, value, parser)
      parser.iso8601(value).freeze if value
    rescue ArgumentError, TypeError
      raise InvalidResponse, "#{self.class}##{name}: #{value.inspect} isn't an ISO 8601 #{parser.equal?(Time) ? "time" : "date"}"
    end

    # Build a resource from a JSON object
    #
    # @api private
    # @param type [Class] the resource class
    # @param value [Object] the value
    # @return [Resource] the resource
    # @raise [InvalidResponse] if the value isn't a JSON object
    def build(type, value)
      raise InvalidResponse, "Expected a JSON object for a #{type}, got #{value.class}" unless value.instance_of?(Hash)

      type.new(value)
    end

    # A frozen copy of a value and everything in it
    #
    # The keys of every Hash must be strings, as the keys of JSON are: a reader's name as a Symbol (start_date:) is
    # not the key the reader reads ("startDate"), so it fails here rather than reading as nil. What it's given is
    # left as it was: a String that isn't frozen is copied, not frozen in place. The other values of JSON (numbers,
    # true, false, and nil) are frozen as they are.
    #
    # @api private
    # @param value [Object] the value
    # @return [Object] the copy, frozen
    # @raise [ArgumentError] if a key of a Hash isn't a String
    def deep_freeze(value)
      case value
      when Hash then value.to_h { |key, item| [check(:key, key, String), deep_freeze(item)] }.freeze # a Hash freezes its String keys itself
      when Array then value.map { |item| deep_freeze(item) }.freeze
      when String then -value
      else value
      end
    end
  end
  private_constant :Wrapping
end
