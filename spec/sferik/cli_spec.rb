# frozen_string_literal: true

require "stringio"

RSpec.describe Sferik::CLI do
  # A client that answers every request with the path and media type it was asked for, and the host it was made for
  # if that isn't sferik.net
  let(:client) do
    Class.new do
      def initialize(host:) = @from = (" from #{host}" unless host.eql?("https://sferik.net"))

      def get(path, accept:) = "#{path} as #{accept}#{@from}\n"

      def write(message) = "write: #{message.inspect} sent to sferik#{@from}"
    end
  end
  let(:usage) { described_class.const_get(:USAGE) }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  # A client that fails every request
  def failing(error, message = nil)
    Class.new do
      define_method(:initialize) { |host:| }
      define_method(:get) { |*, **| raise(error, message) }
      define_method(:write) { |*| raise(error, message) }
    end
  end

  # A client that answers every request with a body
  def answering(body)
    Class.new do
      define_method(:initialize) { |host:| }
      define_method(:get) { |*, **| body }
    end
  end

  # Run a command line, and return its exit status, output, and errors. The command returns its status and leaves
  # exiting to the executable: OptionParser's own --help and --version exit, so one of those answering is a failure
  def run_cli(*argv, with: client, env: {}, input: StringIO.new)
    [described_class.new(client: with, input:, out:, err:, env:).run(argv), out.string, err.string]
  rescue SystemExit
    raise "The command exited, rather than return its status"
  end

  described_class.const_get(:COMMANDS).each do |command, path|
    it "#{command} prints #{path} as text" do
      expect(run_cli(command)).to eq([0, "#{path} as text/plain\n", ""])
    end
  end

  it "prints the home page with no command" do
    expect(run_cli).to eq([0, "/ as text/plain\n", ""])
  end

  %w[-h --help help].each do |flag|
    it "prints the usage for #{flag}" do
      expect(run_cli(flag)).to eq([0, usage, ""])
    end
  end

  it "lists each command in the usage" do
    expect(usage).to start_with("Usage: sferik [options] [command]\n\n  finger         how to reach me\n")
  end

  it "lists every command in the usage" do
    expect(usage.scan(/^  (\S+)  /).flatten).to contain_exactly(*described_class.const_get(:COMMANDS).keys, "write", "help")
  end

  %w[-v --version].each do |flag|
    it "prints the version for #{flag}" do
      expect(run_cli(flag)).to eq([0, "#{Sferik::VERSION}\n", ""])
    end
  end

  it "says what's wrong with an unknown command, then the usage" do
    expect(run_cli("nope")).to eq([2, "", "sferik: unknown command: nope\n\n#{usage}"])
  end

  it "says what's wrong with an argument after the command, then the usage" do
    expect(run_cli("finger", "foo", "bar")).to eq([2, "", "sferik: unexpected argument: foo\n\n#{usage}"])
  end

  it "prints the usage for --help with a command too" do
    expect(run_cli("--help", "finger")).to eq([0, usage, ""])
  end

  it "prints the version for --version with a command too" do
    expect(run_cli("finger", "--version")).to eq([0, "#{Sferik::VERSION}\n", ""])
  end

  it "lists every option in the usage" do
    expect(usage.scan(/(?<= )--?[a-z]+/)).to eq(%w[--json --pdf --latex --host -h --help -v --version])
  end

  it "prints a command as JSON with --json" do
    expect(run_cli("talks", "--json")).to eq([0, "/talks as application/json\n", ""])
  end

  it "takes --json before the command too" do
    expect(run_cli("--json", "talks")).to eq([0, "/talks as application/json\n", ""])
  end

  it "takes --json after the command with POSIXLY_CORRECT set too" do
    stub_const("ENV", ENV.to_h.merge("POSIXLY_CORRECT" => "1"))

    expect(run_cli("talks", "--json")).to eq([0, "/talks as application/json\n", ""])
  end

  it "prints the home page as JSON with --json and no command" do
    expect(run_cli("--json")).to eq([0, "/ as application/json\n", ""])
  end

  it "prints the resume as a PDF with --pdf" do
    expect(run_cli("resume", "--pdf")).to eq([0, "/resume as application/pdf\n", ""])
  end

  it "prints the resume as LaTeX with --latex" do
    expect(run_cli("resume", "--latex")).to eq([0, "/resume as application/x-latex\n", ""])
  end

  [%w[--json --latex], %w[--latex --pdf], %w[--pdf --json], %w[--json --pdf --json]].each do |formats|
    it "says to pick one format for #{formats.join(" ")}, then the usage, and asks for nothing" do
      expect(run_cli("resume", *formats)).to eq([2, "", "sferik: pick one format: --json, --pdf, or --latex\n\n#{usage}"])
    end
  end

  it "takes a format named twice" do
    expect(run_cli("resume", "--json", "--json")).to eq([0, "/resume as application/json\n", ""])
  end

  [%w[--help], %w[-h], %w[help], %w[--version], %w[-v], %w[finger --help], %w[finger --version]].each do |argv|
    %w[--json --pdf --latex].each do |format|
      it "takes no #{format} for #{argv.join(" ")}, which prints no resource: it says so, then the usage" do
        expect(run_cli(*argv, format)).to eq([2, "", "sferik: --json, --pdf, and --latex are for the commands that print a resource\n\n#{usage}"])
      end
    end
  end

  it "says that an unknown command is one, whatever format is named with it" do
    expect(run_cli("nope", "--json")).to eq([2, "", "sferik: unknown command: nope\n\n#{usage}"])
  end

  it "prints a binary body, as a PDF is, in binary mode" do
    allow(out).to receive(:binmode).and_call_original
    run_cli("resume", "--pdf", with: answering("%PDF-1.7\n".b))

    expect(out).to have_received(:binmode)
  end

  it "prints the bytes of a binary body as they are" do
    expect(run_cli("resume", "--pdf", with: answering("%PDF-1.7\n\xE2".b))).to eq([0, "%PDF-1.7\n\xE2".b, ""])
  end

  it "says to redirect a binary body rather than print it to a terminal, and fails" do
    allow(out).to receive(:tty?).and_return(true)

    expect(run_cli("resume", "--pdf", with: answering("%PDF-1.7\n".b)))
      .to eq([1, "", "sferik: binary output would garble the terminal: redirect it to a file (sferik resume --pdf > resume.pdf)\n"])
  end

  it "leaves the output of a binary body it doesn't print in the mode it is in" do
    allow(out).to receive_messages(tty?: true, binmode: out)
    run_cli("resume", "--pdf", with: answering("%PDF-1.7\n".b))

    expect(out).not_to have_received(:binmode)
  end

  it "prints text to a terminal" do
    allow(out).to receive(:tty?).and_return(true)

    expect(run_cli("resume")).to eq([0, "/resume as text/plain\n", ""])
  end

  it "prints text in the mode the output is in" do
    allow(out).to receive(:binmode).and_call_original
    run_cli("resume")

    expect(out).not_to have_received(:binmode)
  end

  it "write sends the message that standard input has, and prints what the server says" do
    expect(run_cli("write", input: StringIO.new("Hello\nfrom a pipe\n"))).to eq([0, "write: \"Hello\\nfrom a pipe\\n\" sent to sferik\n", ""])
  end

  it "write says how to end a message before it reads one from a terminal, as an error" do
    terminal = instance_double(IO, tty?: true, read: "Hello\n")

    expect(run_cli("write", input: terminal)).to eq(
      [0, "write: \"Hello\\n\" sent to sferik\n", "Type your message, then Ctrl-D to send it, or Ctrl-C to cancel. Include your email address if you'd like a reply.\n"]
    )
  end

  %w[--json --pdf --latex].each do |format|
    it "takes no #{format} for write: it says so, then the usage, and reads and sends nothing" do
      input = StringIO.new("Hello")

      expect([*run_cli("write", format, input:), input.pos]).to eq(
        [2, "", "sferik: --json, --pdf, and --latex are for the commands that print a resource\n\n#{usage}", 0]
      )
    end
  end

  it "write asks the host --host names" do
    expect(run_cli("write", "--host", "http://localhost:3745", input: StringIO.new("Hello"))).to eq([0, "write: \"Hello\" sent to sferik from http://localhost:3745\n", ""])
  end

  it "write reports errors from the API, and fails" do
    expect(run_cli("write", with: failing(Sferik::Error, "write: nothing to send"))).to eq([1, "", "sferik: write: nothing to send\n"])
  end

  it "write stops quietly when interrupted before the message ends, and sends nothing" do
    terminal = instance_double(IO, tty?: false)
    allow(terminal).to receive(:read).and_raise(Interrupt)

    expect(run_cli("write", input: terminal)).to eq([130, "", ""])
  end

  it "reads a message from stdin by default" do
    stub_request(:post, "https://sferik.net/write").with(body: "Hello").to_return(status: 202, body: %({"message":"message sent to sferik"}\n), headers: {"Content-Type" => "application/json; charset=utf-8"})
    allow($stdin).to receive_messages(tty?: false, read: "Hello")

    expect { described_class.new.run(["write"]) }.to output("message sent to sferik\n").to_stdout
  end

  it "asks the host --host names" do
    expect(run_cli("finger", "--host", "http://localhost:3745")).to eq([0, "/finger as text/plain from http://localhost:3745\n", ""])
  end

  it "asks the host --host names for the home page too" do
    expect(run_cli("--host=http://localhost:3745")).to eq([0, "/ as text/plain from http://localhost:3745\n", ""])
  end

  it "asks the host SFERIK_HOST names" do
    expect(run_cli("finger", env: {"SFERIK_HOST" => "http://localhost:3745"})).to eq([0, "/finger as text/plain from http://localhost:3745\n", ""])
  end

  it "asks the host --host names rather than the one SFERIK_HOST does" do
    expect(run_cli("finger", "--host", "http://localhost:1", env: {"SFERIK_HOST" => "http://localhost:2"})).to eq([0, "/finger as text/plain from http://localhost:1\n", ""])
  end

  it "asks the configured host without either" do
    Sferik.host = "http://localhost:3745"

    expect(run_cli("finger")).to eq([0, "/finger as text/plain from http://localhost:3745\n", ""])
  end

  it "says what's wrong with a host that isn't a URL, with the status of a command line that's wrong" do
    expect(run_cli("finger", "--host", "localhost:3745", with: Sferik::Client)).to eq([2, "", "sferik: host must be an http or https URL, not \"localhost:3745\"\n"])
  end

  it "says what's wrong with a SFERIK_HOST that isn't a URL, with the status of a command line that's wrong" do
    expect(run_cli("finger", with: Sferik::Client, env: {"SFERIK_HOST" => "localhost:3745"})).to eq([2, "", "sferik: host must be an http or https URL, not \"localhost:3745\"\n"])
  end

  it "says what's wrong with an unknown option, then the usage" do
    expect(run_cli("--nope")).to eq([2, "", "sferik: invalid option: --nope\n\n#{usage}"])
  end

  it "says what's wrong with --host without a URL, then the usage" do
    expect(run_cli("finger", "--host")).to eq([2, "", "sferik: missing argument: --host\n\n#{usage}"])
  end

  it "raises an ArgumentError that isn't about the host, which is a bug rather than a mistake of the command line's" do
    expect { run_cli("finger", with: failing(ArgumentError, "wrong number of arguments")) }.to raise_error(ArgumentError, "wrong number of arguments")
  end

  it "raises a kind of ArgumentError that isn't about the host too" do
    expect { run_cli("finger", with: failing(Date::Error, "invalid date")) }.to raise_error(Date::Error, "invalid date")
  end

  it "reports errors from the API, and fails" do
    expect(run_cli("finger", with: failing(Sferik::NetworkError, "Failed to open TCP connection"))).to eq([1, "", "sferik: Failed to open TCP connection\n"])
  end

  it "stops quietly when what reads its output has gone" do
    closed = instance_double(IO)
    allow(closed).to receive(:print).and_raise(Errno::EPIPE)

    expect([described_class.new(client:, out: closed, err:, env: {}).run(["finger"]), err.string]).to eq([0, ""])
  end

  it "stops quietly when interrupted, with the status of a SIGINT" do
    expect(run_cli("finger", with: failing(Interrupt))).to eq([130, "", ""])
  end

  it "uses a client for sferik.net and prints to stdout by default" do
    stub_request(:get, "https://sferik.net/finger").with(headers: {"Accept" => "text/plain"}).to_return(body: "Login: sferik\n")
    expect { described_class.new.run(["finger"]) }.to output("Login: sferik\n").to_stdout
  end

  it "reads SFERIK_HOST from the environment by default" do
    stub_request(:get, "http://localhost:3745/finger").to_return(body: "Login: sferik\n")
    stub_const("ENV", ENV.to_h.merge("SFERIK_HOST" => "http://localhost:3745"))

    expect { described_class.new.run(["finger"]) }.to output("Login: sferik\n").to_stdout
  end

  it "asks the configured host when SFERIK_HOST is set but empty" do
    Sferik.host = "http://localhost:3745"

    expect(run_cli("finger", env: {"SFERIK_HOST" => ""})).to eq([0, "/finger as text/plain from http://localhost:3745\n", ""])
  end

  it "prints errors to stderr by default" do
    expect { described_class.new.run(["nope"]) }.to output(/\Asferik: unknown command: nope/).to_stderr
  end

  it "runs from the sferik executable" do
    expect(File.read(File.expand_path("../../exe/sferik", __dir__))).to include("exit Sferik::CLI.new.run(ARGV)")
  end
end
