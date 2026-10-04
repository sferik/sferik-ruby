# Security Policy

## Supported versions

Security fixes are released for the most recent minor release. Older releases are not patched, so upgrading is the
way to receive a fix.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |

## Reporting a vulnerability

Please do not report security vulnerabilities through public GitHub issues, pull requests, or discussions. Instead,
use [GitHub's private vulnerability reporting](https://github.com/sferik/sferik-ruby/security/advisories/new), or email
[sferik@gmail.com](mailto:sferik@gmail.com).

Include the version of the gem, the Ruby version, and the steps to reproduce the problem. You can expect an
acknowledgment within a few days.

## What this library handles

This library reads public data from sferik.net, and sends no credentials or cookies. It sends data of yours only when
you call one of the two methods that write: `check_in` sends the token and page you give it, and `write` sends the
message you give it, which is emailed on. It already takes these precautions, so a way around one of them is a
vulnerability rather than a feature request:

* TLS certificates are verified (Net::HTTP's default), and no option turns that off.
* Redirects are followed only to http and https URLs, never from https to http, and at most `max_redirects` times
  (10 by default), so a response cannot send the client to another scheme, off TLS, or around in a loop. A POST's
  redirects are never followed, so a message goes only to the host it was sent to.
* Responses are parsed with `JSON.parse`, which creates no objects other than Hashes, Arrays, Strings, numbers,
  booleans, and nil, and a response that isn't a JSON object is rejected with `Sferik::InvalidResponse`.
* Response objects are deeply frozen, so one shared between threads cannot be changed by any of them.
