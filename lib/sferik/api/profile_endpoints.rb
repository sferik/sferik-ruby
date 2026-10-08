# frozen_string_literal: true

require "uri"
require_relative "../dependency"
require_relative "../finger"
require_relative "../home"
require_relative "../name_change"
require_relative "../validation"
require_relative "../web_finger"
require_relative "../whoami"

module Sferik
  module API
    # The endpoints about Erik: the bio, the comic, contact details, the name change, the motto, and the account
    # @api public
    module ProfileEndpoints
      include Validation

      # Returns the profile and the home page's modules
      #
      # The home page builds itself from these.
      #
      # @api public
      # @return [Home]
      # @example
      #   Sferik.home.profile.tagline
      def home
        json("") { |attributes| Home.new(attributes) }
      end

      # Returns the bio: paragraphs of HTML
      #
      # @api public
      # @return [Whoami]
      # @example
      #   Sferik.whoami.blocks.map(&:html)
      def whoami
        json("/whoami") { |attributes| Whoami.new(attributes) }
      end

      # Returns the xkcd comic on the home page: xkcd 2347, adapted
      #
      # @api public
      # @return [Dependency]
      # @example
      #   Sferik.dependency.figure.alt
      def dependency
        json("/dependency") { |attributes| Dependency.new(attributes) }
      end

      # Returns contact details and profiles elsewhere
      #
      # @api public
      # @return [Finger]
      # @example
      #   Sferik.finger.profiles.map(&:url)
      def finger
        json("/finger") { |attributes| Finger.new(attributes) }
      end

      # Returns contact details and profiles as a contact card (a vCard)
      #
      # It's what an address book imports: the name, the email address, and each profile elsewhere.
      #
      # @api public
      # @return [String] the vCard
      # @example
      #   File.write("erik-berlin.vcf", Sferik.finger_vcard)
      def finger_vcard
        get("/finger", accept: "text/vcard")
      end

      # Returns the name change, from Erik Michaels-Ober to Erik Berlin, as a git commit
      #
      # @api public
      # @return [NameChange]
      # @example
      #   Sferik.name_change.year # => 2017
      def name_change
        json("/name") { |attributes| NameChange.new(attributes) }
      end

      # Returns the motto: ~/.signature, which the home page shows as cat .signature
      #
      # @api public
      # @return [String] the motto, without the newline the site ends it with
      # @example
      #   Sferik.signature # => "I build libraries and tools software engineers depend on."
      def signature
        get("/.signature", accept: "text/plain").chomp
      end

      # Returns where an account at sferik.net points to, as WebFinger answers
      #
      # WebFinger is RFC 7033. That's the account on Mastodon, which makes the domain a fediverse handle. The same
      # account is at sferik.com, sferik.org, and sferik.me.
      #
      # @api public
      # @param resource [String] the account, as an acct: URI
      # @return [WebFinger]
      # @raise [ArgumentError] if the account isn't a String
      # @raise [NotFound] if there's no such account: {HTTPError#error_code} is "no_account"
      # @example
      #   Sferik.webfinger.subject # => "acct:sferik@mastodon.social"
      # @example Ask after the account at another of the domains
      #   Sferik.webfinger("acct:sferik@sferik.org")
      def webfinger(resource = "acct:sferik@sferik.net")
        query = URI.encode_www_form(resource: check(:resource, resource, String))
        json("/.well-known/webfinger?#{query}", accept: "application/jrd+json") { |attributes| WebFinger.new(attributes) }
      end
    end
  end
end
