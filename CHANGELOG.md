# Changelog

## 0.0.1 (2026-10-08)

- Initial release: every endpoint of the sferik.net API (`home`, `whoami`, `dependency`, `finger`, `finger_vcard`,
  `name_change`, `signature`, `webfinger`, `contributions`, `projects`, `talks`, `talks_feed`, `podcasts`, `resume`,
  `resume_latex`, `resume_pdf`, `who`, `deployment`, `status`, `text`, `openapi`, and the two that write, `check_in` and
  `write`), on `Sferik` itself or on a client of your own (`Sferik.new`)
- Immutable response objects, typed all the way down (`Sferik::Resume::Work`, `Sferik::Home::Profile`, and so on),
  with every date a `Date` or `Time`, and with equality, pattern matching, `to_h`, `to_json`, and `as_json`. Everything
  inside one is built when it is, so a response that isn't what the API documents raises `InvalidResponse` from the
  endpoint that got it, not from a reader later on
- `Sferik.projects`, `Sferik.talks`, and `Sferik.who` are Enumerable, over their projects, talks, and terminals, with
  `size`, `length`, `empty?`, `last`, and `[]` as well, and they match array patterns (`in [newest, *]`). Their `to_h`
  is of their readers, like any resource's, and with a block it's of the list, like an Array's
- `Sferik.check_in(token)` checks in a terminal, as each browser tab on the site does (on the home page, or on the
  one that `page:` names), and returns who's reading with the terminal's name as `you`. `Sferik.write("...")` sends
  Erik a message, as the shell's `write sferik` does. Each message goes with a random key (or the one `key:` gives),
  which the server doesn't email twice, so `write` sends it once more, five seconds later, if it was sent and no answer
  came (`Unanswered`), but not if the server couldn't be connected to. And if the server says the message is still
  being sent (a 409), `write` asks after it once more, as much later as the server says to
- `Sferik.contributions` and `Sferik.projects` say when their numbers are from, as `as_of`, and whether that's
  now, as `live?`: it's false for a snapshot, and for numbers the site last fetched more than two hours ago. `as_of`
  is to the hour, so that numbers that haven't changed are the same response, which a cached client isn't sent again
- `Sferik.status` says whether the site gets its numbers from GitHub as it should, with its token: when GitHub was
  last asked with it, when it last answered, and what went wrong if it didn't. The numbers are live either way, since
  the site asks another way when the token fails. And it says when the site last loaded each of its live values, as
  `loaded`: the downloads and the contributions, which say so themselves, and the stars and the latest push, which
  say so nowhere else
- `Sferik.client.get` and `Sferik.client.post` send raw requests. A GET's redirects are followed, up to
  `max_redirects` (10), but never from https to http. A POST is sent only once, and its redirects aren't followed. Its
  body is sent as UTF-8, converted from the charset of the String it's given (a binary or US-ASCII one is taken for
  UTF-8 already), with an `Idempotency-Key` header if `idempotency_key:` gives one
- A thread's requests to the site are made over one connection, left open between them, where each would otherwise
  connect again: with https, most of the time a request takes. One that has sat unused for half a minute is opened
  again. Each thread, fiber, and process has its own.
  `Sferik.client.keep_alive { |client| ... }` makes the requests in its block over a connection of their own, which
  is closed when the block ends, and `Sferik.client.close` closes the ones the thread has open
- `Sferik.client.cached` is a client that keeps the responses to its GETs for as long as each says it's good for, and
  after that asks with the response's ETag, so the server sends the body only if it has changed. A response that has
  been kept on its way already (`Age`) is good for that much less. Each request it makes says not to be answered from
  a cache (`Cache-Control: no-cache`), so the site builds a new response where it would have sent one that's no longer
  good, and sends what's still good as it is. A server error (a 5xx)
  leaves what's kept as it is, to be asked after again. With `cached(stale_if_error: true)`, the client
  answers with what it kept, however old, when the server can't be reached. Threads that ask it for the same thing
  at once make one request between them, and what an endpoint builds of a response is kept with it, so the JSON of
  one that's kept is parsed once. It keeps a hundred responses at most, the latest it asked for
- Configuration, with `Sferik.configure` or the options of `Sferik.new`: `host`, `user_agent`, `open_timeout`,
  `read_timeout`, `write_timeout`, `max_redirects`, and `cache`, which makes the client one that keeps its responses,
  as `cached` returns, so that `Sferik.who` and the rest do. A wrong one raises ArgumentError when the client is built
- Errors are all `Sferik::Error`: `InvalidURL`, `NetworkError` (and `Unanswered`, for a request that was sent and got
  no answer), `TooManyRedirects`, `InvalidResponse`, and `HTTPError`
  (`ClientError`, `NotFound`, `NotAcceptable`, `TooManyRequests`, and `ServerError`), which has the response's `code`,
  `headers`, and `body`, what the server says went wrong as its message, which error it is as `error_code` (`"busy"` or
  `"full"` for the `TooManyRequests` that `write` raises past its rate limit), and the seconds to wait as `retry_after`,
  where the response says. One can be raised by hand with nothing but its class (`raise Sferik::NotFound`), which gives
  it its code
- A `sferik` command, which prints what the shell on sferik.net prints: `sferik finger`, `sferik resume`, and so on.
  With `--json` it prints JSON instead, `sferik resume --pdf` and `sferik resume --latex` print the resume as a PDF and
  as LaTeX, `sferik finger --vcard` prints a contact card, and `--host` or the `SFERIK_HOST` environment variable names
  a copy of the site to ask instead of sferik.net. `sferik feed`, `sferik deployment`, `sferik status`, and
  `sferik openapi` print the talks as an Atom feed, the deployed commit, whether GitHub answers the site with its token,
  and the API's description, and `sferik signature` and `sferik webfinger` the motto, and where sferik@sferik.net points
  to.
  `sferik write` sends Erik the message it reads from standard input, and `sferik check-in` logs in a terminal and
  prints its name, which `sferik write --tty` takes. It exits 1 when a request fails, and 2 when the command line is
  wrong, as one that names two formats is, or a format for what prints no resource (`sferik write`, `sferik help`, or
  `sferik --version`) or one that comes in one format alone (`sferik feed`)
- The command loads the client only when it asks the site for something: `sferik --version` and `sferik --help`
  don't wait for it
- RBS signatures, checked by Steep
