# frozen_string_literal: true

require_relative "resource"
require_relative "resume/award"
require_relative "resume/basics"
require_relative "resume/education"
require_relative "resume/meta"
require_relative "resume/patent"
require_relative "resume/project"
require_relative "resume/skill"
require_relative "resume/speaking"
require_relative "resume/volunteer"
require_relative "resume/work"

module Sferik
  # The resume, a JSON Resume document (https://jsonresume.org/schema), as returned by {API::ResumeEndpoints#resume}
  #
  # Its sections are objects of their own, under this class: {Basics}, {Work}, {Award}, and so on.
  # @api public
  class Resume < Resource
    # @!method basics
    #   The name, contact details, summary, and location
    #   @api public
    #   @return [Basics] the name, contact details, summary, and location
    #   @example
    #     resume.basics # => #<Sferik::Resume::Basics ...>
    attribute :basics, "basics", type: Basics

    # @!method work
    #   Jobs, newest first
    #   @api public
    #   @return [Array<Work>] jobs, newest first
    #   @example
    #     resume.work # => [#<Sferik::Resume::Work ...>, ...]
    list :work, "work", type: Work

    # @!method projects
    #   Open source work
    #   @api public
    #   @return [Array<Project>] open source work
    #   @example
    #     resume.projects # => [#<Sferik::Resume::Project ...>, ...]
    list :projects, "projects", type: Project

    # @!method skills
    #   Skills, by group
    #   @api public
    #   @return [Array<Skill>] skills, by group
    #   @example
    #     resume.skills # => [#<Sferik::Resume::Skill ...>]
    list :skills, "skills", type: Skill

    # @!method awards
    #   Honors
    #   @api public
    #   @return [Array<Award>] honors
    #   @example
    #     resume.awards # => [#<Sferik::Resume::Award ...>, ...]
    list :awards, "awards", type: Award

    # @!method patents
    #   Patents
    #   @api public
    #   @return [Array<Patent>] patents
    #   @example
    #     resume.patents # => [#<Sferik::Resume::Patent ...>, ...]
    list :patents, "patents", type: Patent

    # @!method speaking
    #   A summary of talks
    #   @api public
    #   @return [Speaking] a summary of talks
    #   @example
    #     resume.speaking # => #<Sferik::Resume::Speaking ...>
    attribute :speaking, "speaking", type: Speaking

    # @!method education
    #   Schools
    #   @api public
    #   @return [Array<Education>] schools
    #   @example
    #     resume.education # => [#<Sferik::Resume::Education ...>]
    list :education, "education", type: Education

    # @!method volunteer
    #   Service
    #   @api public
    #   @return [Array<Volunteer>] service
    #   @example
    #     resume.volunteer # => [#<Sferik::Resume::Volunteer ...>, ...]
    list :volunteer, "volunteer", type: Volunteer

    # @!method meta
    #   What the resume says about itself, or nil if it says nothing
    #   @api public
    #   @return [Meta, nil] what the resume says about itself, or nil if it says nothing
    #   @example
    #     resume.meta # => #<Sferik::Resume::Meta ...>
    attribute :meta, "meta", type: Meta

    inspect_with :name

    # The name on the resume, from {#basics}
    #
    # @api public
    # @return [String, nil] the name
    # @example
    #   resume.name # => "Erik Berlin"
    def name
      basics&.name
    end
    record :name

    # When the resume last changed, from {#meta}
    #
    # @api public
    # @return [Date, nil] when the resume last changed
    # @example
    #   resume.last_modified # => #<Date: 2026-10-01>
    def last_modified
      meta&.last_modified
    end
    record :last_modified
  end
end
