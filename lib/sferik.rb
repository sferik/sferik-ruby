# frozen_string_literal: true

require "forwardable"
require_relative "sferik/client"
require_relative "sferik/configuration"
require_relative "sferik/version"

# A Ruby wrapper for the sferik.net API
#
# Every public method of {API} is a method of this module too, delegated to {.client}: {API::ProfileEndpoints#whoami}
# is `Sferik.whoami`, {API::ResumeEndpoints#resume} is `Sferik.resume`, and so on for every endpoint. {API} groups them
# into one mixin per topic, and each is documented there.
#
# @api public
# @see API The endpoints, grouped into one mixin per topic
module Sferik
  # The sferik command, loaded when it's first used: a program that only calls the API doesn't load it, or optparse
  autoload :CLI, "#{__dir__}/sferik/cli"

  extend Configuration
  extend SingleForwardable

  # The mutex that guards the client the API methods of the module delegate to
  CLIENT_MUTEX = Mutex.new
  private_constant :CLIENT_MUTEX

  # @!method self.new(**options)
  #   Alias for Sferik::Client.new
  #   @api public
  #   @param options [Hash] options passed to {Sferik::Client#initialize}
  #   @return [Sferik::Client] a new client
  #   @example Create a client for a local copy of the site
  #     Sferik.new(host: "http://localhost:3745")
  def_delegator "Sferik::Client", :new

  # The endpoints of {API}, each delegated to the client the module has, and documented here so that each is found
  # under the name it's called by
  #
  # @!method self.home
  #   Returns the profile and the home page's modules
  #   @api public
  #   @return [Home]
  #   @example
  #     Sferik.home.profile.tagline
  #   @see API::ProfileEndpoints#home What it raises, and more about it
  # @!method self.whoami
  #   Returns the bio: paragraphs of HTML
  #   @api public
  #   @return [Whoami]
  #   @example
  #     Sferik.whoami.blocks.map(&:html)
  #   @see API::ProfileEndpoints#whoami What it raises, and more about it
  # @!method self.dependency
  #   Returns the xkcd comic on the home page: xkcd 2347, adapted
  #   @api public
  #   @return [Dependency]
  #   @example
  #     Sferik.dependency.figure.alt
  #   @see API::ProfileEndpoints#dependency What it raises, and more about it
  # @!method self.finger
  #   Returns contact details and profiles elsewhere
  #   @api public
  #   @return [Finger]
  #   @example
  #     Sferik.finger.profiles.map(&:url)
  #   @see API::ProfileEndpoints#finger What it raises, and more about it
  # @!method self.finger_vcard
  #   Returns contact details and profiles as a contact card (a vCard)
  #   @api public
  #   @return [String] the vCard
  #   @example
  #     File.write("erik-berlin.vcf", Sferik.finger_vcard)
  #   @see API::ProfileEndpoints#finger_vcard What it raises, and more about it
  # @!method self.name_change
  #   Returns the name change, from Erik Michaels-Ober to Erik Berlin, as a git commit
  #   @api public
  #   @return [NameChange]
  #   @example
  #     Sferik.name_change.year # => 2017
  #   @see API::ProfileEndpoints#name_change What it raises, and more about it
  # @!method self.contributions
  #   Returns a year of GitHub contributions, the longest streak, and the latest push
  #   @api public
  #   @return [Contributions]
  #   @example
  #     Sferik.contributions.days.max_by(&:count).date
  #   @see API::CodeEndpoints#contributions What it raises, and more about it
  # @!method self.projects
  #   Returns projects with their RubyGems downloads and GitHub stars
  #   @api public
  #   @return [Projects]
  #   @example
  #     Sferik.projects.total_downloads # => 5_460_234_129
  #   @see API::CodeEndpoints#projects What it raises, and more about it
  # @!method self.talks
  #   Returns conference talks, newest first, and podcast appearances
  #   @api public
  #   @return [Talks]
  #   @example
  #     Sferik.talks.select(&:video).map(&:title)
  #   @see API::TalkEndpoints#talks What it raises, and more about it
  # @!method self.talks_feed
  #   Returns the talks as an Atom feed, newest first
  #   @api public
  #   @return [String] the feed, as XML
  #   @example
  #     File.write("talks.atom", Sferik.talks_feed)
  #   @see API::TalkEndpoints#talks_feed What it raises, and more about it
  # @!method self.podcasts
  #   Returns podcast appearances
  #   @api public
  #   @return [Array<Podcast>]
  #   @example
  #     Sferik.podcasts.first.show # => "Ruby Rogues, episode 248"
  #   @see API::TalkEndpoints#podcasts What it raises, and more about it
  # @!method self.resume
  #   Returns the resume as a JSON Resume document
  #   @api public
  #   @return [Resume]
  #   @example
  #     Sferik.resume.work.first.position
  #   @see API::ResumeEndpoints#resume What it raises, and more about it
  # @!method self.resume_latex
  #   Returns the resume as a LaTeX document, ready for pdflatex or tectonic
  #   @api public
  #   @return [String] the LaTeX source
  #   @example
  #     File.write("resume.tex", Sferik.resume_latex)
  #   @see API::ResumeEndpoints#resume_latex What it raises, and more about it
  # @!method self.resume_pdf
  #   Returns the resume as a two-page PDF
  #   @api public
  #   @return [String] the PDF, as binary
  #   @example
  #     File.binwrite("resume.pdf", Sferik.resume_pdf)
  #   @see API::ResumeEndpoints#resume_pdf What it raises, and more about it
  # @!method self.who
  #   Returns everyone reading the site right now
  #   @api public
  #   @return [Who]
  #   @example
  #     Sferik.who.map(&:page) # => ["/", "/talks"]
  #   @see API::SiteEndpoints#who What it raises, and more about it
  # @!method self.check_in(token, page: "/")
  #   Checks in a terminal, and returns everyone reading the site
  #   @api public
  #   @param token [String] a random token, one per terminal, of 16 to 64 letters, digits, underscores, and hyphens
  #   @param page [String] the page the terminal is on: "/", "/talks", or "/resume"
  #   @return [Who] everyone reading the site, with the terminal that checked in as {Who#you}
  #   @example
  #     Sferik.check_in(SecureRandom.uuid).you # => "ttys001"
  #   @see API::SiteEndpoints#check_in What it raises, and more about it
  # @!method self.write(message, tty: nil, key: SecureRandom.uuid)
  #   Sends Erik a message, as the shell's write sferik does
  #   @api public
  #   @param message [String] the message, as plain text: 5,000 bytes at most, sent as UTF-8
  #   @param tty [String, nil] the sender's terminal, for the subject line: {Who#you}, from {.check_in}
  #   @param key [String] a random key, one per message: the server doesn't email a message twice whose key it has taken
  #   @return [String] what the server says: "message sent to sferik"
  #   @example
  #     Sferik.write("Hello from Ruby. Reply to me@example.com")
  #   @see API::SiteEndpoints#write What it raises, and more about it
  # @!method self.text(path = "")
  #   Returns a resource as terminal output, wrapped to 80 columns
  #   @api public
  #   @param path [String] the resource's path: "/whoami", "/resume" (as a man page), etc. (defaults to the home page)
  #   @return [String] the text
  #   @example
  #     puts Sferik.text("/resume")
  #   @see API::SiteEndpoints#text What it raises, and more about it
  # @!method self.openapi
  #   Returns the API's OpenAPI 3.1 description
  #   @api public
  #   @return [Hash{String => Object}] the parsed document, deep-frozen
  #   @example
  #     Sferik.openapi["paths"].keys
  #   @see API::SiteEndpoints#openapi What it raises, and more about it
  # @!method self.deployment
  #   Returns which commit of the site is deployed, and when it was
  #   @api public
  #   @return [Deployment]
  #   @example
  #     Sferik.deployment.commit # => "6a34226a3f351a78339b75430055a018ac30c964"
  #   @see API::SiteEndpoints#deployment What it raises, and more about it
  def_delegators :client, *API.public_instance_methods

  # The methods of SingleForwardable, which the module delegates with rather than offers (one at a time: YARD can't
  # read the names of a splat)
  SingleForwardable.instance_methods.each { |name| private_class_method name }

  # The client the API methods of the module delegate to
  #
  # The client is built from the global configuration, and built again whenever that configuration changes.
  #
  # @api public
  # @return [Client] the client
  # @example Perform a raw request with the module's client
  #   Sferik.client.get("/whoami", accept: "text/plain")
  def self.client
    CLIENT_MUTEX.synchronize do
      @client = nil unless options.eql?(@client_options)
      @client_options = options
      @client ||= new
    end
  end

  # Reset the global configuration and forget the client
  #
  # @api public
  # @return [self]
  # @example Reset the configuration
  #   Sferik.reset
  def self.reset
    CLIENT_MUTEX.synchronize do
      @client = @client_options = nil
      super
    end
  end
end
