# frozen_string_literal: true

require "optparse"
require "securerandom"
require_relative "../sferik"

module Sferik
  # The sferik command: prints what the shell on sferik.net prints, in a real terminal
  #
  # Each command prints a resource of the site as text, the same text `curl sferik.net/finger` gets, or with --json
  # as JSON. The resume also comes as a PDF with --pdf, and as LaTeX with --latex, and finger as a contact card with
  # --vcard. The write command sends me what it reads from standard input, as the shell's write sferik does, and the
  # check-in command logs in a terminal, as each browser tab on the site does, and prints its name. It asks sferik.net, or a copy of the site at the URL
  # that --host or the SFERIK_HOST environment variable names.
  #
  # @api public
  # @example
  #   Sferik::CLI.new.run(["finger"])          # prints how to reach me, and returns 0
  #   Sferik::CLI.new.run(["talks", "--json"]) # prints my talks as JSON
  #   Sferik::CLI.new.run(["resume", "--pdf"]) # prints my resume as a PDF
  #   Sferik::CLI.new.run(["write"])           # sends me a message, read from standard input
  #   Sferik::CLI.new.run(["check-in"])        # logs in a terminal, and prints its name
  class CLI
    # The commands, and the path of the resource each one prints
    COMMANDS = {
      "finger" => "/finger", "whoami" => "/whoami", "talks" => "/talks", "podcasts" => "/podcasts", "resume" => "/resume", "who" => "/who",
      "contributions" => "/contributions", "src" => "/src", "name" => "/name", "dependency" => "/dependency"
    }.freeze
    private_constant :COMMANDS

    # What sferik --help prints
    USAGE = <<~TEXT
      Usage: sferik [options] [command]

        finger         how to reach me
        whoami         who is this
        talks          my talks and podcasts
        podcasts       my podcast appearances
        resume         my resume, as a man page
        contributions  a year of GitHub contributions
        src            my open source projects
        name           my name change, as a git commit
        dependency     the xkcd comic, in words
        who            who's reading sferik.net
        write          send me a message, read from standard input
        check-in       log in a terminal, as a browser tab does, and print its name
        help           print this

      With no command, sferik prints the home page.

      Options:
            --json       print JSON, not text
            --pdf        print a PDF, for the resume: redirect it to a file
            --latex      print LaTeX, for the resume
            --vcard      print a contact card, for finger
            --tty NAME   for write: the terminal the message is from, as check-in names it
            --token KEY  for check-in: the terminal's token, to keep its name (random, by default)
            --host URL   ask a copy of the site at URL (or set SFERIK_HOST)
        -h, --help       print this
        -v, --version    print the version
    TEXT
    private_constant :USAGE

    # What sferik write says before it reads a message from a terminal
    PROMPT = "Type your message, then Ctrl-D to send it, or Ctrl-C to cancel. Include your email address if you'd like a reply.\n"
    private_constant :PROMPT

    # The options that name a format, and the media type each asks for
    FORMATS = {"--json" => "application/json", "--pdf" => "application/pdf", "--latex" => "application/x-latex", "--vcard" => "text/vcard"}.freeze

    # The options that take a value, and what each is noted as
    VALUES = {"--tty NAME" => :tty, "--token KEY" => :token, "--host URL" => :host}.freeze

    # The options that are for one command alone, and the command each is for
    OWNERS = {tty: "write", token: "check-in"}.freeze

    # What prints no resource of the site, by the command or option that asks for it, and the method that does each
    ACTIONS = {:usage => :usage, "help" => :usage, :version => :version, "write" => :write, "check-in" => :check_in}.freeze
    private_constant :FORMATS, :VALUES, :OWNERS, :ACTIONS

    # Initialize a new CLI
    #
    # @api public
    # @param client [#new] what makes the client for a host (the {Client} class)
    # @param input [IO] where sferik write reads a message from
    # @param out [IO] where output goes
    # @param err [IO] where errors go
    # @param env [#fetch] the environment, for SFERIK_HOST
    # @return [CLI] a new instance
    # @example
    #   Sferik::CLI.new(env: {"SFERIK_HOST" => "http://localhost:3745"})
    def initialize(client: Client, input: $stdin, out: $stdout, err: $stderr, env: ENV)
      @client = client
      @input = input
      @out = out
      @err = err
      @env = env
    end

    # Run a command
    #
    # @api public
    # @param argv [Array<String>] the command line, without the program's name
    # @return [Integer] the exit status: 0, 1 for a request that fails, 2 for a command line that's wrong (an unknown
    #   command or option, more than one format, a format for what prints no resource, or an option for another
    #   command), or 130 when interrupted
    # @example
    #   Sferik::CLI.new.run(["talks"]) # => 0
    def run(argv)
      dispatch(argv)
    rescue OptionParser::ParseError => e
      misuse(e)
    rescue Errno::EPIPE # what reads the output (head, say) has all it wants
      0
    rescue Interrupt
      130
    end

    private

    # Run the command a command line names
    #
    # @api private
    # @param argv [Array<String>] the command line
    # @return [Integer] the exit status
    # @raise [OptionParser::ParseError] if an option is unknown, or --host has no URL
    def dispatch(argv)
      options = {accept: []} #: Hash[Symbol, untyped]
      command, extra = parser(options).permute(argv) # parse would take no option after the command with POSIXLY_CORRECT set
      return misuse("unexpected argument: #{extra}") if extra

      option, owner = OWNERS.find { |name, its| options.key?(name) && !its.eql?(command) }
      option ? misuse("--#{option} is for #{owner}") : perform(command, options)
    end

    # Do what a command line asks for
    #
    # That's to print a resource, or what an option or a command that prints none names.
    #
    # @api private
    # @param command [String, nil] the command, or nil for the home page
    # @param options [Hash{Symbol => Object}] the options of the command line
    # @return [Integer] the exit status
    def perform(command, options)
      action = ACTIONS[options.fetch(:print, command)]
      return unformatted(options) { __send__(action, options) } if action

      path = command ? COMMANDS[command] : "/"
      path ? show(path, options) : misuse("unknown command: #{command}")
    end

    # Print the usage
    #
    # @api private
    # @param _options [Hash{Symbol => Object}] the options of the command line, which make no difference
    # @return [Integer] the exit status
    def usage(_options) = say(USAGE)

    # Print the version
    #
    # @api private
    # @param _options [Hash{Symbol => Object}] the options of the command line, which make no difference
    # @return [Integer] the exit status
    def version(_options) = say("#{VERSION}\n")

    # What reads the options of a command line
    #
    # @api private
    # @param options [Hash{Symbol => Object}] where to note the options: the media types to :accept, which it adds each
    #   format named to, the :host to ask, what to :print instead of a resource (:usage or :version), the :tty a
    #   message is from, and the :token to check in with
    # @return [OptionParser] the parser
    def parser(options)
      OptionParser.new do |flags|
        FORMATS.each { |flag, type| flags.on(flag) { options[:accept] |= [type] } }
        VALUES.each { |flag, name| flags.on(flag) { |value| options[name] = value } }
        flags.on("-h", "--help") { options[:print] = :usage }
        flags.on("-v", "--version") { options[:print] = :version }
      end
    end

    # Print a resource of the site, as text or in the format an option names
    #
    # A PDF is printed as it is: Windows would otherwise write each of its line feeds as a carriage return and one.
    # It isn't printed to a terminal, which its bytes would garble. A resource comes in one format at a time, so
    # options that name two are the command line's mistake.
    #
    # @api private
    # @param path [String] the resource's path
    # @param options [Hash{Symbol => Object}] the options of the command line
    # @return [Integer] the exit status
    def show(path, options)
      return misuse("pick one format: --json, --pdf, --latex, or --vcard") if options.fetch(:accept).size > 1

      ask(options) { |client| client.get(path, accept: [*options.fetch(:accept), "text/plain"].first) }
    end

    # Do what takes no format, since it prints no resource of the site
    #
    # That's the usage, the version, sending a message, and checking in: an option that names a format for one of them is the
    # command line's mistake, and nothing is done.
    #
    # @api private
    # @param options [Hash{Symbol => Object}] the options of the command line
    # @yield what to do, if no option names a format
    # @yieldreturn [Integer] the exit status
    # @return [Integer] the exit status
    def unformatted(options)
      return misuse("--json, --pdf, --latex, and --vcard are for the commands that print a resource") if options.fetch(:accept).any?

      yield
    end

    # Send me the message that standard input has, and print what the server says
    #
    # A terminal is told how to end the message first, on standard error, so that the output is the server's alone.
    # With --tty, the message says which terminal it's from.
    #
    # @api private
    # @param options [Hash{Symbol => Object}] the options of the command line
    # @return [Integer] the exit status
    def write(options)
      @err.print(PROMPT) if @input.tty?
      ask(options) { |client| "#{client.write(@input.read, tty: options[:tty])}\n" }
    end

    # Log in a terminal, as each browser tab on the site does, and print its name
    #
    # The name is what write's --tty takes. A terminal keeps it for as long as it checks in with the same token, at
    # least every three minutes: without --token, each check-in is a new terminal's.
    #
    # @api private
    # @param options [Hash{Symbol => Object}] the options of the command line
    # @return [Integer] the exit status: 1 if every terminal is taken
    def check_in(options)
      ask(options) do |client|
        tty = client.check_in(options.fetch(:token) { SecureRandom.uuid }).you
        raise Error, "every terminal is taken: try again in a few minutes" unless tty

        "#{tty}\n"
      end
    end

    # Ask the site for something, and print its response, or what went wrong
    #
    # A host that isn't an http or https URL is the command line's mistake, or the environment's, not a request that
    # failed, so it has the exit status of one. Only the client being built is taken for that: an ArgumentError from
    # the request, or from printing its response, is a bug, and is raised as one.
    #
    # @api private
    # @param options [Hash{Symbol => Object}] the options of the command line
    # @yield [client] the request to make
    # @yieldparam client [Client] a client for the host the options or the environment name, or else the configured one
    # @yieldreturn [String] the body of the response
    # @return [Integer] the exit status: 0, 1 for a request that fails, or 2 for a host that isn't a URL
    # @raise [ArgumentError] if the request, or printing its response, raises one
    def ask(options)
      named = @env.fetch("SFERIK_HOST", "") # one that's set but empty names no host, as if it weren't set
      host = options.fetch(:host) { named.empty? ? Sferik.host : named }
      client = @client.new(host:)
      print_body(yield(client))
    rescue Error, ArgumentError => e
      raise if e.is_a?(ArgumentError) && client # only one from building the client is about the host

      @err.puts("sferik: #{e}")
      e.is_a?(Error) ? 1 : 2
    end

    # Print the body of a response: a binary one, as a PDF is, in binary mode
    #
    # @api private
    # @param body [String] the body
    # @return [Integer] the exit status
    # @raise [Error] if the body is binary and the output is a terminal
    def print_body(body)
      return say(body) unless body.encoding.equal?(Encoding::BINARY)
      raise Error, "binary output would garble the terminal: redirect it to a file (sferik resume --pdf > resume.pdf)" if @out.tty?

      @out.binmode
      say(body)
    end

    # Print text
    #
    # @api private
    # @param text [String] the text
    # @return [Integer] the exit status: 0
    def say(text)
      @out.print(text)
      0
    end

    # Say what's wrong with a command line, then the usage
    #
    # @api private
    # @param problem [#to_s] what's wrong: a message, or an error with one
    # @return [Integer] the exit status: 2, which tells a command line that's wrong from a request that fails
    def misuse(problem)
      @err.print("sferik: #{problem}\n\n#{USAGE}")
      2
    end
  end
end
