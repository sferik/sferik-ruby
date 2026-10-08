# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # Speaking, as returned by {Resume#speaking} (an addition to JSON Resume)
    # @api public
    class Speaking < Resource
      # @!method summary
      #   A summary of talks, with *italic* titles
      #   @api public
      #   @return [String] a summary of talks, with *italic* titles
      #   @example
      #     speaking.summary # => "Spoke at 17 conferences in 13 countries..."
      attribute :summary
    end
  end
end
