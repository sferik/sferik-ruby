# frozen_string_literal: true

require "json"
require_relative "errors"

module Sferik
  # Parses the API's JSON responses, for the endpoints that return objects
  # @api private
  module JSONParsing
    private

    # Parse a JSON response body
    #
    # @api private
    # @param body [String] the response body
    # @return [Hash] the parsed body, deep-frozen
    # @raise [InvalidResponse] if the body isn't a JSON object, or isn't in the charset the response names (or one JSON can be read in)
    def parse_json(body)
      value = JSON.parse(body, freeze: true)
      raise InvalidResponse, "Expected a JSON object, got #{value.class}" unless value.instance_of?(Hash)

      value
    rescue JSON::ParserError, EncodingError => e
      raise InvalidResponse, "Couldn't parse the response as JSON: #{e}"
    end
  end
  private_constant :JSONParsing
end
