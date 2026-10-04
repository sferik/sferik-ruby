# frozen_string_literal: true

require_relative "../resource"

module Sferik
  class Resume < Resource
    # A group of skills, as returned in {Resume#skills}
    # @api public
    class Skill < Resource
      # @!method name
      #   The group
      #   @api public
      #   @return [String] the group
      #   @example
      #     skill.name # => "Languages"
      attribute :name

      # @!method keywords
      #   The skills
      #   @api public
      #   @return [Array<String>] the skills
      #   @example
      #     skill.keywords # => ["Ruby", "Rust", ...]
      list :keywords
    end
  end
end
