# frozen_string_literal: true

require "date"
require "json"
require "time"
require_relative "errors"
require_relative "wrapping"

module Sferik
  # Parses the dates the API gives to the year, month, or day ("2026", "2015-11", "2014-04-22"), as the first day of
  # the period. ISO 8601 allows all three, but Date.iso8601 doesn't take a year alone, and on JRuby not a month either.
  #
  # @api private
  module PartialDate
    # Parse a date given to the year, month, or day
    #
    # @api private
    # @param value [String] the date
    # @return [Date] the date, or the first day of the year or month
    # @raise [Date::Error] if the value isn't an ISO 8601 date
    # @example
    #   Sferik::PartialDate.iso8601("2015-11") # => #<Date: 2015-11-01>
    def self.iso8601(value)
      Date.iso8601(
        case value
        when /\A\d{4}\z/ then "#{value}-01-01"
        when /\A\d{4}-\d{2}\z/ then "#{value}-01"
        else value
        end
      )
    end
  end
  private_constant :PartialDate

  # Base class for objects that wrap sferik.net API responses
  #
  # A resource is immutable: its attributes are deep-frozen, and two resources with the same attributes are equal.
  # It works with pattern matching, with the names of its readers as keys: a predicate's without its question mark,
  # so that a pattern can bind it. A reader of a list returns an empty one when the response has none.
  #
  # The resources inside one are built when it is, and so are its dates and times, so a response that isn't what the
  # API documents raises {InvalidResponse} from the endpoint that got it, not from a reader later on. A reader returns
  # the same frozen object each time it's called.
  #
  # @api public
  # @example Pattern matching
  #   case Sferik.contributions
  #   in {total:, longest_streak:, live:} then puts "#{total} contributions, #{longest_streak}-day streak"
  #   end
  class Resource
    include Wrapping

    # What a reader of a list returns when the response has none, and the keys of a resource that reads none
    EMPTY = [].freeze # steep:ignore UnannotatedEmptyCollection
    private_constant :EMPTY

    # The readers of a resource that declares none, and what a reader of a dictionary returns when the response has none
    NONE = {}.freeze # steep:ignore UnannotatedEmptyCollection
    private_constant :NONE

    # The raw attributes from the API response
    # @api public
    # @return [Hash{String => Object}] the raw attributes, frozen
    # @example
    #   talk.attributes["title"]
    attr_reader :attributes

    class << self
      # The names of the readers this resource declares
      #
      # They are the keys of {#to_h}, and of pattern matching. A predicate goes by its name without the question mark: `featured?` is `:featured`.
      #
      # @api public
      # @return [Array<Symbol>] the names, frozen
      # @example
      #   Sferik::Talk.attribute_names # => [:title, :event, :date, :location, :slides, :video, :link, :featured]
      def attribute_names
        readers.keys.freeze
      end

      private

      # The reader each name is read with
      #
      # A resource that declares none has those of the nearest resource it inherits from that does.
      #
      # @api private
      # @return [Hash{Symbol => Symbol}] the readers by name, frozen
      def readers
        ancestors.filter_map { |ancestor| ancestor.instance_variable_get(:@readers) }.first || NONE
      end

      # The keys of the response this resource's readers read
      #
      # A resource that declares no readers has those of the nearest resource it inherits from that does.
      #
      # @api private
      # @return [Array<String>] the keys, frozen
      def keys
        ancestors.filter_map { |ancestor| ancestor.instance_variable_get(:@keys) }.first || EMPTY
      end

      # The blocks that make what this resource prepares when it's built
      #
      # A resource that prepares none has those of the nearest resource it inherits from that does.
      #
      # @api private
      # @return [Hash{Symbol => Proc}] the blocks by name, frozen
      def preparations
        ancestors.filter_map { |ancestor| ancestor.instance_variable_get(:@preparations) }.first || NONE
      end

      # Name a value to prepare when a resource is built
      #
      # The resource then has it as prepared(name).
      #
      # @api private
      # @param name [Symbol] the name of the value
      # @yield what makes the value, run as the resource once it has its attributes
      # @yieldreturn [Object] the value
      # @return [Hash{Symbol => Proc}] the blocks by name, frozen
      def prepare(name, &value)
        @preparations = preparations.merge(name => value).freeze
      end

      # Define a reader of a value that's prepared when a resource is built
      #
      # @api private
      # @param name [Symbol] the name of the reader
      # @param key [String] the key in the response
      # @yield what makes the value, run as the resource once it has its attributes
      # @yieldreturn [Object] the value
      # @return [Symbol] the name of the reader
      def reader(name, key, &value)
        prepare(name, &value)
        define_method(name) { prepared(name) } # steep:ignore NoMethod
        record(name, key)
      end

      # Define a reader for an attribute
      #
      # @api private
      # @param name [Symbol] the name of the reader
      # @param key [String] the key in the response (defaults to the name, camelCased)
      # @param type [Class, nil] a resource class to wrap the value in
      # @return [Symbol] the name of the reader
      def attribute(name, key = camelize(name), type: nil)
        reader(name, key) { wrap(attributes[key], type) }
      end

      # Define a reader for a list, which is empty when the response has none
      #
      # @api private
      # @param name [Symbol] the name of the reader
      # @param key [String] the key in the response (defaults to the name, camelCased)
      # @param type [Class, nil] a resource class to wrap each value of the list in
      # @return [Symbol] the name of the reader
      def list(name, key = camelize(name), type: nil)
        reader(name, key) { wrap_list(name, given(attributes[key], EMPTY), type) }
      end

      # Define a predicate for a boolean attribute
      #
      # @api private
      # @param name [Symbol] the name of the attribute (the reader is suffixed with a question mark)
      # @param key [String] the key in the response
      # @return [Symbol] the name of the attribute
      def predicate(name, key = camelize(name))
        reader = :"#{name}?"
        define_method(reader) do
          # @type self: Resource
          attributes[key].eql?(true)
        end
        record(name, key, reader:)
      end

      # Define a reader for a dictionary, which is empty when the response has none
      #
      # A dictionary is a JSON object of resources by name.
      #
      # @api private
      # @param name [Symbol] the name of the reader
      # @param key [String] the key in the response (defaults to the name, camelCased)
      # @param type [Class] a resource class to wrap each value of the dictionary in
      # @return [Symbol] the name of the reader
      def dictionary(name, key = camelize(name), type:)
        reader(name, key) { wrap_dictionary(name, given(attributes[key], NONE), type) }
      end

      # Define a reader that parses an ISO 8601 date or time
      #
      # @api private
      # @param name [Symbol] the name of the reader
      # @param parser [#iso8601] Time, Date, or {PartialDate} for a date that may be given to the year or month
      # @param key [String] the key in the response
      # @return [Symbol] the name of the reader
      def timestamp(name, parser, key = camelize(name))
        reader(name, key) { wrap_timestamp(name, attributes[key], parser) }
      end

      # Name the readers that #inspect shows (the first three, unless declared)
      #
      # A resource whose first readers are long lists names shorter ones, to be read at a glance in a console.
      #
      # @api private
      # @param names [Array<Symbol>] the readers, or any other public methods
      # @return [Array<Symbol>] the readers
      def inspect_with(*names)
        @inspected = names
      end

      # The readers #inspect shows
      #
      # A resource that names none has those of the nearest resource it inherits from that does.
      #
      # @api private
      # @return [Array<Symbol>] the readers
      def inspected
        ancestors.filter_map { |ancestor| ancestor.instance_variable_get(:@inspected) }.first || attribute_names.first(3)
      end

      # Note a reader and the key it reads
      #
      # @api private
      # @param name [Symbol] the name the reader goes by
      # @param key [String, nil] the key, or nil for a reader that reads nested keys itself
      # @param reader [Symbol] the reader, if it isn't the name: a predicate's has a question mark
      # @return [Symbol] the name
      def record(name, key = nil, reader: name)
        @readers = readers.merge(name => reader).freeze
        @keys = [*keys, key].freeze if key
        name
      end

      # The key a reader reads by default: its name, camelCased
      #
      # @api private
      # @param name [Symbol] the reader
      # @return [String] the key
      def camelize(name)
        name.to_s.gsub(/_[a-z]/) { |match| match.delete_prefix("_").upcase }
      end
    end

    # Initialize a new resource
    #
    # The attributes are copied, and the copy frozen: what's given is left as it was. Their keys are the keys of the
    # API's JSON, which are strings, at every depth: "startDate", not the name of the reader that reads it.
    #
    # The resources inside this one are built here, and its dates and times parsed, so what the readers return is
    # checked once, now, rather than each time one is called.
    #
    # @api public
    # @param attributes [Hash{String => Object}] the attributes from the API response
    # @return [Resource] a new resource
    # @raise [ArgumentError] if the attributes aren't a Hash, or a key of theirs isn't a String, at any depth
    # @raise [InvalidResponse] if a value isn't what the API documents, at any depth: a list that isn't a JSON array, a
    #   resource that isn't a JSON object, or a date or time that isn't an ISO 8601 one
    # @example
    #   Sferik::Talk.new("title" => "Writing Fast Ruby")
    def initialize(attributes)
      @attributes = deep_freeze(check(:attributes, attributes, Hash))
      @prepared = self.class.__send__(:preparations).transform_values { |value| instance_exec(&value) }.freeze
      freeze
    end

    # The attributes, read through the readers this resource declares
    #
    # @api public
    # @return [Hash{Symbol => Object}] the values of the readers
    # @example
    #   talk.to_h # => {title: "Writing Fast Ruby", ...}
    def to_h
      self.class.attribute_names.to_h { |name| [name, read(name)] }
    end

    # The resource as JSON: the JSON it came from
    #
    # @api public
    # @param args [Array<Object>] what JSON.generate passes on: the state of the generator
    # @return [String] the raw attributes, as JSON
    # @example
    #   talk.to_json # => "{\"title\":\"Writing Fast Ruby\",...}"
    def to_json(*args)
      attributes.to_json(*args) # steep:ignore UnexpectedPositionalArgument
    end

    # The resource as ActiveSupport makes JSON of it: the JSON it came from
    #
    # ActiveSupport asks for this when a resource is inside something else it makes JSON of. Without it, a resource
    # in a Hash that Rails renders as JSON would be its instance variables, and one that's Enumerable would be a list.
    #
    # @api public
    # @param _options [Array<Object>] the options ActiveSupport passes on, which make no difference
    # @return [Hash{String => Object}] the raw attributes, frozen
    # @example
    #   talk.as_json # => {"title" => "Writing Fast Ruby", ...}
    def as_json(*_options)
      attributes
    end

    # The keys pattern matching asks for, from {#to_h}
    #
    # @api public
    # @param keys [Array<Symbol>, nil] the keys asked for, or nil for all of them
    # @return [Hash{Symbol => Object}] the values
    # @example
    #   case talk
    #   in {title:, event:, featured:} then "#{title} at #{event}#{" (featured)" if featured}"
    #   end
    def deconstruct_keys(keys)
      names = keys ? self.class.attribute_names & keys : self.class.attribute_names
      names.to_h { |name| [name, read(name)] }
    end

    # Whether another object is a resource of the same class with the same attributes
    #
    # @api public
    # @param other [Object] the other object
    # @return [Boolean]
    # @example
    #   Sferik.whoami == Sferik.whoami # => true
    def ==(other)
      other.instance_of?(self.class) && other.attributes.eql?(attributes)
    end
    alias_method :eql?, :==

    # A hash code, so equal resources can be keys of the same Hash entry
    #
    # @api public
    # @return [Integer] the hash code
    # @example
    #   {talk => true}
    def hash
      [self.class, attributes].hash
    end

    # A short description of the resource
    #
    # A date is shown as its day alone, without the Julian day numbers Date#inspect adds.
    #
    # @api public
    # @return [String] the description
    # @example
    #   talk.inspect # => "#<Sferik::Talk title=\"Writing Fast Ruby\" ...>"
    def inspect
      shown = self.class.__send__(:inspected).map do |name|
        "#{name}=#{read(name).then { |value| value.instance_of?(Date) ? "#<Date: #{value}>" : value.inspect }}"
      end
      "#<#{[self.class, *shown].join(" ")}>"
    end

    private

    # A value that was prepared when the resource was built
    #
    # @api private
    # @param name [Symbol] the name the value was prepared under
    # @return [Object] the value
    def prepared(name)
      @prepared.fetch(name)
    end

    # Read the value a name goes by
    #
    # @api private
    # @param name [Symbol] the name of a reader, or of any other public method
    # @return [Object] the value
    def read(name)
      public_send(self.class.__send__(:readers).fetch(name, name))
    end
  end
end
