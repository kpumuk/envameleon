<a id="readme-top"></a>

<div align="center">
  <img src="assets/envameleon.png" alt="ENVameleon — Leave no ENVidence." width="800">

  <h1>ENVameleon</h1>
  <p><strong>Leave no ENVidence.</strong></p>
  <p>Hide the first process environment shown by Linux without changing Ruby's <code>ENV</code>.</p>
  <p>
    <a href="#about">About</a> ·
    <a href="#getting-started">Get started</a> ·
    <a href="#usage">Usage</a> ·
    <a href="#how-it-works">How it works</a> ·
    <a href="#development">Development</a>
  </p>
</div>

## Table of Contents

- [About](#about)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [How It Works](#how-it-works)
- [Process Inheritance](#process-inheritance)
- [Security Limits](#security-limits)
- [Development](#development)
- [License](#license)

## About

Linux exposes the environment passed at process start through
`/proc/self/environ`. ENVameleon lets a Ruby process mask, scrub, or drop that
view after boot. Ruby's live `ENV` stays intact.

### Why this matters

Suppose your app keeps its credentials in an encrypted file. Your container
runner passes the unlock key through the process environment. The encrypted
file may seem safe even if an attacker can read any file that the app can
access.

Guess again. Linux also exposes `/proc/self/environ` as a file. It may hold the
unlock key passed at process launch. An attacker who reads both files can
decrypt the credentials, recover a session signing key, and forge sessions.

ENVameleon removes this copy of the key from the proc view after app boot.

The gem has no runtime dependencies. Loading it does not change anything. Your
app chooses when to call one of its three methods.

## Getting Started

### Requirements

- CRuby 3.2 or newer
- Linux for changes to `/proc/self/environ`
- The Linux `CAP_SYS_RESOURCE` right only for `ENV.drop_proc_data`

On other systems, all three methods are safe no-ops.

### Installation

Install the gem:

```console
gem install envameleon
```

Or add it to your `Gemfile`:

```ruby
gem "envameleon"
```

Then load it:

```ruby
require "envameleon"
```

[Back to top](#readme-top).

## Usage

```ruby
require "envameleon"

ENV.mask_proc_data
# SECRET=example becomes SECRET=e*****e in /proc/self/environ

ENV.scrub_proc_data
# /proc/self/environ now holds only NUL bytes

ENV.drop_proc_data
# /proc/self/environ is now zero bytes long
```

| Method | Result in `/proc/self/environ` | File length | Permissions |
| --- | --- | --- | --- |
| `ENV.mask_proc_data` | Names plus the first and last value byte | Unchanged | None |
| `ENV.scrub_proc_data` | NUL bytes | Unchanged | None |
| `ENV.drop_proc_data` | Empty | Zero | `CAP_SYS_RESOURCE` |

Choose the least power you need.

> [!IMPORTANT]
> `ENV.drop_proc_data` requires `CAP_SYS_RESOURCE` on Linux. Without it, the
> method raises `Errno::EPERM`.

Masking works on raw bytes, not characters. It replaces all value bytes except
the first and last with `*`. Values shorter than three bytes stay unchanged.

[Back to top](#readme-top).

## How It Works

CRuby moves its active environment during startup. Linux still keeps the old
range used by `/proc/self/environ`. ENVameleon reads that range from
`/proc/self/stat`.

Masking and scrubbing first check that Ruby no longer uses the old range. They
then change those bytes in place. If Ruby still uses any of them, the method
raises an error and changes nothing.

Dropping uses `PR_SET_MM_ENV_END` to move the end of the kernel's view to its
start. This makes `/proc/self/environ` truly zero-length. Linux requires the
`CAP_SYS_RESOURCE` right for that call.

## Process Inheritance

Call a method before `fork` and each child inherits the changed proc view. Ruby
`ENV` remains available in the parent and children. The test suite checks this
with a second fork for all three methods.

`spawn`, `system`, and `exec` are different. They give the new program a fresh
proc environment. That program must load ENVameleon and call a method itself.

### Forking servers

You may call a method in the parent before it forks. You may also call it from a
worker boot hook. These examples use scrubbing, which needs no extra right.

#### Unicorn

```ruby
require "envameleon"

after_fork do |_server, _worker|
  ENV.scrub_proc_data
end
```

#### Puma

Use `before_worker_boot` for cluster workers. In single mode, call the method
during app boot.

```ruby
require "envameleon"

before_worker_boot do
  ENV.scrub_proc_data
end
```

#### Sidekiq

Standard Sidekiq uses threads. Its startup hook runs before work begins. Sidekiq
Enterprise Swarm runs the hook in each child.

```ruby
require "envameleon"

Sidekiq.configure_server do |config|
  config.on(:startup) { ENV.scrub_proc_data }
end
```

#### Karafka

The `app.running` event runs in the server process. In Swarm mode, it runs in
each forked node.

```ruby
require "envameleon"

Karafka::App.monitor.subscribe("app.running") do
  ENV.scrub_proc_data
end
```

If a child calls `ENV.drop_proc_data`, it must still have the needed Linux right.

[Back to top](#readme-top).

## Security Limits

ENVameleon changes only what `/proc/self/environ` shows. It does not erase every
copy of a secret. It gives no protection from memory disclosure, debuggers, or
core dumps.

Dropping leaves the old bytes in memory. Masking keeps variable names and the
outer bytes of each value. Short values remain fully visible. Scrubbing
overwrites the old proc range, but a secret may still exist elsewhere.

`CAP_SYS_RESOURCE` grants powers beyond changing this proc view. Give it to a
process only when you accept those powers. Masking and scrubbing do not
need it.

[Back to top](#readme-top).

## Development

Build the native extension and run the `test/unit` suite:

```console
ruby -Cext/envameleon extconf.rb
make -C ext/envameleon
ruby -Ilib -Iext test/test_envameleon.rb
```

On Linux, the drop test runs when `CAP_SYS_RESOURCE` is available. Otherwise,
that one test is omitted.

Build the gem with:

```console
gem build envameleon.gemspec
```

## License

Distributed under the MIT License. See `LICENSE.txt`.

[Back to top](#readme-top).
