# sferik

A Ruby wrapper for the [sferik.net](https://sferik.net) API: Erik Berlin's bio, GitHub contributions, projects, talks,
and resume.

## Installation

```sh
bundle add sferik
```

Or, without Bundler:

```sh
gem install sferik
```

It needs Ruby 3.4 or later, or JRuby 10 or later, and is tested on Linux, macOS, and Windows.

## Documentation

[rubydoc.info/gems/sferik](https://rubydoc.info/gems/sferik/). The API itself is described by an OpenAPI 3.1 document at
[sferik.net/openapi.json](https://sferik.net/openapi.json).

## Usage

```ruby
require "sferik"
```

### The bio

```ruby
whoami = Sferik.whoami
whoami.blocks.map(&:html)  # => ["I've spent nearly two decades writing software...", ...]
whoami.multi_downloads     # => 1_780_609_860
```

### The comic

```ruby
figure = Sferik.dependency.figure  # xkcd 2347, adapted
figure.src                         # => "/img/dependency.webp"
figure.alt                         # => "A tall, precarious tower of blocks labeled “all modern Ruby infrastructure,”..."
```

### Contact details

```ruby
finger = Sferik.finger
finger.mail                   # => "sferik@gmail.com"
finger.profiles.map(&:url)    # => ["https://github.com/sferik", "https://gitlab.com/sferik", ...]

File.write("erik-berlin.vcf", Sferik.finger_vcard)  # the same, as a contact card for an address book
```

### The motto, and the account

```ruby
Sferik.signature  # => "I build libraries and tools software engineers depend on."
```

sferik@sferik.net is a fediverse handle: the site answers WebFinger for it, and points to the account on Mastodon.

```ruby
webfinger = Sferik.webfinger
webfinger.subject            # => "acct:sferik@mastodon.social"
webfinger.aliases            # => ["https://mastodon.social/@sferik", "https://mastodon.social/users/sferik"]
webfinger.links.map(&:rel)   # => ["http://webfinger.net/rel/profile-page", "self", "http://ostatus.org/schema/1.0/subscribe"]

Sferik.webfinger("acct:sferik@sferik.org")  # the same account, at sferik.com, sferik.org, and sferik.me too
```

### GitHub contributions

```ruby
contributions = Sferik.contributions
contributions.total                      # => 7747
contributions.longest_streak             # => 32
contributions.days.max_by(&:count).date  # => #<Date: 2026-08-28>
contributions.last_push                  # => #<Sferik::Push repo="sferik/x-ruby" sha="d30399b..." at=2026-10-06 16:18:55 UTC>
contributions.as_of                      # => 2026-10-08 01:15:02 UTC, when the numbers were fetched
```

### Projects

```ruby
projects = Sferik.projects  # Enumerable: most downloaded first, with related projects together
projects.first              # => #<Sferik::Project name="multi_json" description="One interface to every Ruby JSON library." downloads=1173210700>
projects.map(&:name)        # => ["multi_json", "multi_xml", "simplecov", ...]
projects.size               # => 28; there's length, empty?, last, and [] too
projects.total_downloads    # => 5_473_478_762, across every gem @sferik owns
projects.filter_map(&:downloads).sum  # of those listed: downloads is nil for a project that isn't a gem
projects.as_of              # => 2026-10-08 01:15:02 UTC, when the downloads were fetched
```

### Talks

```ruby
talks = Sferik.talks                # Enumerable: newest first
talks.select(&:video).map(&:title)  # => ["The Value of Being Lazy, or How I Made OpenStruct 10X Faster", ...]
talks.first.date                    # => #<Date: 2016-08-01>, the first day of the month it was in
talks.last.title                    # the oldest; there's size, length, empty?, and [] too
talks.places[talks.first.location]  # => #<Sferik::Place lat=37.77 lon=-122.42 country="United States">
talks.filter_map(&:link)            # => ["https://schedule.sxsw.com/2015/events/event_IAP35000"]: a talk's page on the event's site
talks.speaker_deck                  # => "https://speakerdeck.com/sferik"
Sferik.podcasts.first.show          # => "Ruby Rogues, episode 248": the podcasts alone, which the talks have too
Sferik.talks_feed                   # the talks as an Atom feed, for a feed reader
```

### The resume

```ruby
resume = Sferik.resume              # a JSON Resume document (https://jsonresume.org)
resume.name                         # => "Erik Berlin"
resume.work.first.position          # => "Founder"
resume.work.first.start_date        # => #<Date: 2023-01-01>
resume.work.first.end_date          # => nil, since it hasn't ended
resume.patents.map(&:number)        # => ["US20110153423A1", "US20110153414A1"]
resume.last_modified                # => #<Date: 2026-10-07>

File.binwrite("resume.pdf", Sferik.resume_pdf)
File.write("resume.tex", Sferik.resume_latex)
puts Sferik.text("/resume")         # as a man page
```

### Who's reading the site

```ruby
who = Sferik.who   # Enumerable: a terminal per browser tab with the site open
who.size           # => 2
who.map(&:page)    # => ["/", "/talks"]
who.first.login    # => 2026-10-06 12:00:00 UTC
```

To be one of them, check in, as each browser tab does every minute: a terminal is logged in for three minutes after
it last checked in, and keeps its name for as long as it checks in with the same token.

```ruby
require "securerandom"

token = SecureRandom.uuid             # random, one per terminal
who = Sferik.check_in(token)          # on the home page; or Sferik.check_in(token, page: "/talks")
who.you                               # => "ttys001", your terminal
who.size                              # => 3, with you
```

### Send me a message

```ruby
Sferik.write("Hello from Ruby. Reply to me@example.com")  # => "message sent to sferik"
Sferik.write("Hello again", tty: who.you)                 # names your terminal in the subject line
```

The message is emailed to me, with a Reply-To if it includes an email address. It can be 5,000 bytes at most, and the
server takes one a minute from an address and twenty a day in all: past that, it raises `Sferik::TooManyRequests`,
with what the server says as its message, the seconds to wait as `retry_after`, and which limit it was as `error_code`
(`"busy"` or `"full"`). It's sent as UTF-8: a String in another charset is converted, and a binary or US-ASCII one
(what Ruby reads with no locale set) is taken for UTF-8 already.

Each message goes with a random key, and the server doesn't email one twice whose key it has taken within a day. So
if the message is sent and no answer comes (`Sferik::Unanswered`), `write` sends it once more, five seconds later. It
doesn't if the server couldn't be connected to at all (any other `Sferik::NetworkError`), when nothing was sent and
trying again at once wouldn't help. A message asked after while its first sending is still on its way gets a 409
from the server, which says how long to wait: `write` waits that long and asks once more, by when the server usually
knows the message was sent. If it's still on its way then, `write` raises the `Sferik::ClientError` (409), with
`error_code` `"sending"` and the seconds to wait as `retry_after`. To try again
yourself after a `Sferik::NetworkError`, give the key:

```ruby
key = SecureRandom.uuid
begin
  Sferik.write("Hello from Ruby", key:)
rescue Sferik::NetworkError
  sleep 5
  retry
end
```

### Which version of the site is deployed

```ruby
deployment = Sferik.deployment
deployment.commit    # => "6a34226a3f351a78339b75430055a018ac30c964"
deployment.deployed  # => 2026-10-07 18:04:11 UTC
deployment.url       # => "https://github.com/sferik/sferik-web/commit/6a34226a3f351a78339b75430055a018ac30c964"
```

### Anything as terminal output

Every resource also comes as text, wrapped to 80 columns, the way `curl sferik.net` shows it:

```ruby
puts Sferik.text            # the whole home page
puts Sferik.text("/talks")
```

### Raw requests

```ruby
Sferik.client.get("/whoami", accept: "text/plain")
Sferik.client.post("/write", "Hello", accept: "text/plain")  # the body is sent as plain text
Sferik.client.post("/write", "Hello", idempotency_key: SecureRandom.uuid)
```

### Connections

A thread's requests are made over one connection, which saves connecting again for each: with https, that's most of
the time a request takes. Each thread (or fiber) has its own, as a connection is for one at a time, and so does each
process, so a fork doesn't use its parent's.

```ruby
Sferik.whoami  # opens a connection
Sferik.talks   # uses it
Sferik.resume  # and again: three requests in about half the time
```

One that sits unused for more than half a minute is opened again, and so is one the server has closed by then. It's
left open, and closed when its thread is collected, or the process ends. For connections that are closed when
you're done with them, make the requests in `keep_alive`:

```ruby
Sferik.client.keep_alive do |client|
  [client.whoami, client.talks, client.resume]  # one connection of its own, closed when the block ends
end
```

The client it yields has the options of the one it's called on, and is for one thread at a time.

To close the connections a thread has open, whenever you like, call `close`. The next request opens one again:

```ruby
Sferik.whoami
Sferik.client.close  # before a fork, say, though a child never uses its parent's anyway
```

### Asking only for what has changed

Each GET asks the server. A client from `cached` keeps the responses instead: one says how long it's good for (an
hour for what changes only when the site is deployed, five minutes for what has live numbers in it, and five seconds
for who's reading), and for that long the client answers with it, without a request. After that it asks with the response's ETag, and the server sends the body only if it has changed.

```ruby
client = Sferik.client.cached
client.talks  # asks the server
client.talks  # doesn't, for an hour; after that, asks whether the talks have changed
```

With `Sferik.cache = true` (or `Sferik.new(cache: true)`), the client is one that keeps its responses from the start,
so the methods on `Sferik` itself do: `Sferik.who`, called each second, asks the server every five.

What it keeps is in memory, by URL and format, for as long as the client is (a hundred responses at most, the latest
it asked for), so keep the client: each call of
`cached` starts with nothing kept. It's safe to share between threads, and works in `keep_alive` too. Threads that ask
for the same thing at once make one request between them: the first asks, and the rest wait for its answer.

What an endpoint builds of a response is kept with it: for as long as the client answers with the response it kept,
`client.talks` is the same object, and the JSON isn't parsed again. Everything in it is frozen, so that's safe to share.

A response that Cloudflare's cache answered with has been kept there for a while already, which it says (`Age`), and
is good for that much less here: one that's good for five minutes, and has been kept for four, is asked for again in
one. One that comes older than it's good for is asked for once more, at once: Cloudflare's cache answers with what it
has while it builds another, and the second request gets that one.

When the server can't be reached to say whether a response that's no longer good has changed, the request raises
`NetworkError`, as any other would, and when the server answers with an error of its own (a 5xx), `ServerError`. The
response stays kept either way, and the next request asks after it again. A script that would rather go on with what
it last knew can ask for that:

```ruby
client = Sferik.client.cached(stale_if_error: true)
client.talks  # asks the server
client.talks  # an hour later, with the network down, or the server answering 503: the talks it kept
```

## The sferik command

The gem comes with a `sferik` command, which prints what the shell on sferik.net prints, in your terminal:

```sh
gem install sferik
sferik finger    # how to reach me
sferik resume    # my resume, as a man page
sferik --help    # every command and option
```

The commands that print are `finger`, `whoami`, `talks`, `podcasts`, `resume`, `contributions`, `src`, `name`, `dependency`, and
`who`; with none, it prints the home page. With `--json`, a command prints JSON instead of text:

```sh
sferik talks --json | jq -r '.talks[].title'
```

Five more print what comes in one format alone, and take no format: `signature` (my motto), `webfinger` (where
sferik@sferik.net points to, as JSON), `feed` (my talks, as an Atom feed), `deployment` (which commit of the site is
deployed, and when, as JSON), and `openapi` (the description of the API, as JSON):

```sh
sferik deployment | jq -r .commit
```

The resume also comes as a PDF with `--pdf`, and as LaTeX with `--latex`, and `finger` as a contact card with
`--vcard`:

```sh
sferik resume --pdf > resume.pdf
sferik resume --latex > resume.tex
sferik finger --vcard > erik-berlin.vcf
```

`sferik write` sends me a message, as `write sferik` does in the shell on the site. It reads the message from
standard input: type it and press Ctrl-D, or pipe it in.

```sh
echo "Hello from my terminal. Reply to me@example.com" | sferik write
```

`sferik check-in` logs in a terminal, as each browser tab on the site does, and prints its name, which `write` takes
as `--tty`, to say which terminal a message is from. A terminal is logged in for three minutes after it last checked
in, and keeps its name if it checks in again with the same `--token` (16 to 64 letters, digits, hyphens, and
underscores); without one, each check-in is a new terminal's.

```sh
tty=$(sferik check-in)                    # => ttys003, say
echo "Hello from $tty" | sferik write --tty "$tty"
```

It exits 0 when it has printed what it was asked for, 1 when a request fails (the site can't be reached, or says
no), and 2 when the command line is wrong (an unknown command or option, more than one format, a format for
what prints no resource, or one that comes in one format alone (`write`, `check-in`, `help`, `--version`, `signature`, `webfinger`, `feed`, `deployment`, or `openapi`), `--tty` or `--token` for another command, or a host that isn't an http or https URL, from `--host`
or `SFERIK_HOST`), so a script can tell the two apart.

To ask a local copy of the site instead of sferik.net, name it with `--host` or the `SFERIK_HOST` environment
variable (one that's set but empty counts as not set):

```sh
sferik finger --host http://localhost:3745
SFERIK_HOST=http://localhost:3745 sferik finger
```

## Response objects

Endpoints return immutable objects, nested where the response is: a resume's jobs are `Sferik::Resume::Work` objects,
for example. Two with the same attributes are equal, and they work with pattern matching. Dates the API gives to the
month or year, like a talk's, are the first day of that month or year. A list the response leaves out is empty, not
nil. In a pattern and in `to_h`, a predicate goes by its name without the question mark: `live?` is `live:`. Projects,
talks, and who's reading match array patterns too, and with a block their `to_h` makes a Hash of the list, as an
Array's does (`Sferik.projects.to_h { |project| [project.name, project.stars] }`). One built by hand (`Sferik::Talk.new("title" => "...")`) keeps a
frozen copy of what it's given, and leaves the original as it was. What it's given must be a Hash with the keys of the
API's JSON, which are strings (`"startDate"`, not `start_date:`): anything else raises `ArgumentError`. In Rails, a
resource inside something rendered as JSON is the JSON it came from, since it has `as_json`.

Everything inside a response object is built when it is, so a response that isn't what the API documents raises
`Sferik::InvalidResponse` from the endpoint that got it, never from a reader later on, and a reader returns the same
frozen object each time it's called. Dates and times are frozen too: to see a time in your zone, use `getlocal`, since
`localtime` would change it.

```ruby
case Sferik.contributions
in {total:, longest_streak:, live:}
  puts "#{total} contributions, longest streak #{longest_streak} days#{" (not live)" unless live}"
end

case Sferik.talks
in [newest, *, oldest]
  puts "From #{oldest.title} to #{newest.title}"
end

Sferik.talks.first.to_h       # => {title: "...", event: "...", date: #<Date: 2015-11-01>, ..., featured: true}
Sferik.talks.first.attributes # => the raw JSON, frozen
Sferik.talks.to_json          # => the JSON it came from
```

## Configuration

```ruby
Sferik.configure do |config|
  config.host = "http://localhost:3745" # a local copy of the site
  config.read_timeout = 30
end

# Or build a client of your own
client = Sferik.new(host: "http://localhost:3745")
client.whoami
```

| Setting         | Default                     | Description                                      |
| --------------- | --------------------------- | ------------------------------------------------ |
| `host`          | `"https://sferik.net"`      | The host for API requests, with scheme           |
| `user_agent`    | `"sferik/VERSION (ruby …)"` | The `User-Agent` header                          |
| `open_timeout`  | `5`                         | Seconds to wait for a connection to open         |
| `read_timeout`  | `10`                        | Seconds to wait for a response (see below)       |
| `write_timeout` | `10`                        | Seconds to wait for a request to be sent         |
| `max_redirects` | `10`                        | Redirects to follow (never from https to http)   |
| `cache`         | `false`                     | Keep the responses to GETs (see above)           |

The host must be an http or https URL with no credentials, query, or fragment, the user agent must be on one line, a
timeout must be positive and finite, `max_redirects` can't be negative (0 follows none), and `cache` must be true or
false: anything else raises
`ArgumentError` when the client is built.

A request that times out waiting for a response is sent once more, as Net::HTTP does with any GET, so a response that
never comes takes twice `read_timeout` to raise `Sferik::NetworkError`. A POST is sent only once, and its redirects
aren't followed, except that `write` sends its message once more if no answer comes, since its key makes that safe.

## Errors

Every error is a `Sferik::Error`:

```
Sferik::Error
├── Sferik::InvalidURL         the path can't be in a URL
├── Sferik::NetworkError       the server couldn't be reached, or its response couldn't be read
│   └── Sferik::Unanswered     the request was sent, or may have been, and no answer came that could be read
├── Sferik::TooManyRedirects   redirected more than max_redirects times
├── Sferik::InvalidResponse    the response wasn't what the API documents
└── Sferik::HTTPError          any other response that isn't a success, or a redirect that isn't followed (#code, #headers, #body, #error_code, #retry_after)
    ├── Sferik::ClientError    4xx
    │   ├── Sferik::NotFound         404
    │   ├── Sferik::NotAcceptable    406: no such format for that resource
    │   └── Sferik::TooManyRequests  429: too many messages
    └── Sferik::ServerError    5xx
```

The message of an HTTP error is always UTF-8, whatever charset the response was in. `error_code` is which error it is,
where the API says (`"busy"`, `"too_long"`, `"bad_token"`, `"not_found"`, `"no_account"`, and so on), and `retry_after` is the seconds
to wait before trying again, where the response has a Retry-After header: each is nil otherwise.

One can be raised by hand, as a spec that stubs a request does, with nothing but its class, which gives it its code:

```ruby
allow(Sferik).to receive(:whoami).and_raise(Sferik::NotFound)  # code 404, message "404 Not Found"
raise Sferik::ServerError, "Down for maintenance"              # code 500
```

## Development

```sh
bin/setup                 # install dependencies
bundle exec rake          # everything below
bundle exec rake spec     # specs, with 100% line, branch, and method coverage
bundle exec rake lint     # RuboCop and Standard
bundle exec rake mutant   # mutation tests: every mutant must be killed
bundle exec rake steep    # type-check lib/ against the signatures in sig/
bundle exec rake rbs      # validate the signatures
bundle exec rake yardstick # 100% documentation coverage
bin/console               # an IRB session with the library loaded
```

The specs stub requests with responses saved from the API, in `spec/fixtures/`, alongside the API's OpenAPI
description. A contract spec checks every fixture against its schema there, and every key the library reads against
what its schema documents. To refresh them all from the live site (or a local copy):

```sh
bundle exec rake fixtures
HOST=http://localhost:3745 bundle exec rake fixtures
```

`bundle exec rake drift` checks the saved description against the live one, and fails if the API has changed since.
It runs daily in `.github/workflows/drift.yml`, which opens an issue when it does.

## Supported Ruby versions

Ruby 3.4 and 4.0, and JRuby.

## License

MIT. See [LICENSE.md](LICENSE.md).
