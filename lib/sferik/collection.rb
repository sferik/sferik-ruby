# frozen_string_literal: true

module Sferik
  # What an Array has that Enumerable doesn't, for a resource that's Enumerable over a list: {Projects}, {Talks}, and {Who}
  #
  # @api public
  module Collection
    # How many there are
    #
    # @api public
    # @return [Integer] how many there are
    # @example
    #   Sferik.talks.size # => 18
    def size
      to_a.size
    end
    alias_method :length, :size

    # Whether there are none
    #
    # @api public
    # @return [Boolean]
    # @example
    #   Sferik.talks.empty? # => false
    def empty?
      to_a.empty?
    end

    # The last one, or the last few
    #
    # @api public
    # @param count [Array<Integer>] how many, for more than one
    # @return [Object, Array<Object>, nil] the last one (nil if there are none), or as many as asked for
    # @example
    #   Sferik.talks.last    # => #<Sferik::Talk ...>, the oldest
    #   Sferik.talks.last(3) # => [#<Sferik::Talk ...>, ...]
    def last(*count) # steep:ignore DifferentMethodParameterKind
      to_a.last(*count) # steep:ignore UnresolvedOverloading
    end

    # The one at an index, or those in a range, as Array#[] gives them
    #
    # @api public
    # @param index [Array<Integer, Range>] an index, a start and a length, or a range
    # @return [Object, Array<Object>, nil] the one at the index, or those in the range: nil for one out of range
    # @example
    #   Sferik.talks[0]    # => #<Sferik::Talk ...>, the newest
    #   Sferik.talks[0, 3] # => [#<Sferik::Talk ...>, ...]
    def [](*index) # steep:ignore DifferentMethodParameterKind
      to_a[*index] # steep:ignore UnresolvedOverloading
    end

    # What the readers return, by name, or with a block, a Hash made of each one
    #
    # Enumerable's #to_h makes a Hash of the list, which a resource's has no use for: its own is of its readers. But
    # with a block it's the list that's meant, as it is for anything else that's Enumerable.
    #
    # @api public
    # @yield [item] each one, to make a key and a value of
    # @yieldparam item [Object] one of them
    # @yieldreturn [Array<(Object, Object)>] its key and its value
    # @return [Hash] the values of the readers by name, or with a block, the values it makes by the keys it makes
    # @example
    #   Sferik.projects.to_h                                          # => {projects: [...], total_downloads: 5_460_234_129, ...}
    #   Sferik.projects.to_h { |project| [project.name, project.stars] } # => {"multi_json" => 27, ...}
    def to_h(&)
      block_given? ? to_a.to_h(&) : deconstruct_keys(nil)
    end

    # All of them, for pattern matching against an array pattern
    #
    # @api public
    # @return [Array<Object>] all of them, in order
    # @example
    #   case Sferik.talks
    #   in [newest, *, oldest] then "#{oldest.title} to #{newest.title}"
    #   end
    def deconstruct
      to_a
    end
  end
end
