# frozen_string_literal: true

module Sferik
  # Reads the body of a response in the charset its Content-Type names
  #
  # Net::HTTP leaves the encoding of a body to chance: binary or UTF-8, by how the response happened to be sent. Text
  # and JSON that name no charset are UTF-8, as a proxy that strips the charset leaves the site's, and as JSON always is.
  #
  # @api private
  module Body
    # The charset a Content-Type names, with or without quotes around it
    CHARSET = /;\s*charset="?([^";\s]+)/i
    private_constant :CHARSET

    # A media type that is text or JSON, which is UTF-8 when it names no charset
    TEXT = %r{\A(?:text/|application/json\b)}i
    private_constant :TEXT

    # The body of a response, in the charset its Content-Type names
    #
    # @api private
    # @param response [Net::HTTPResponse] the response
    # @return [String] the body: UTF-8 if it's text or JSON that names no charset, and binary if it's anything else
    #   that names none, or names one Ruby doesn't know
    # @example
    #   Sferik::Body.of(response).encoding # => #<Encoding:UTF-8>
    def self.of(response)
      String.new(response.body.to_s, encoding: encoding_of(response))
    end

    # The encoding the Content-Type of a response names
    #
    # The Content-Type is read here, not by Net::HTTP, which raises NoMethodError for a parameter without a value
    # and takes the quotes around a charset for part of its name.
    #
    # @api private
    # @param response [Net::HTTPResponse] the response
    # @return [Encoding] the encoding: UTF-8 for text or JSON that names no charset, and binary for anything else that
    #   names none, or names one Ruby doesn't know
    # @example
    #   Sferik::Body.encoding_of(response) # => #<Encoding:UTF-8>
    def self.encoding_of(response)
      type = response["content-type"].to_s
      charset = type[CHARSET, 1]
      return Encoding.find(charset) || Encoding::BINARY if charset # "internal" is a name, but may be no encoding

      TEXT.match?(type) ? Encoding::UTF_8 : Encoding::BINARY
    rescue ArgumentError
      Encoding::BINARY
    end
    private_class_method :encoding_of
  end
  private_constant :Body
end
