# frozen_string_literal: true

require_relative "api/code_endpoints"
require_relative "api/profile_endpoints"
require_relative "api/resume_endpoints"
require_relative "api/site_endpoints"
require_relative "api/talk_endpoints"

module Sferik
  # The endpoints of the sferik.net API, grouped into one mixin per topic
  #
  # {Client} includes them all, and {Sferik} delegates each to its client, so every method documented here can be
  # called on either: `Sferik.whoami` or `Sferik::Client.new.whoami`.
  #
  # @api public
  module API
    include CodeEndpoints
    include ProfileEndpoints
    include ResumeEndpoints
    include SiteEndpoints
    include TalkEndpoints
  end
end
