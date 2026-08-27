# proc-environ

`proc-environ` hides or masks the initial environment in
`/proc/self/environ`. It leaves Ruby's `ENV` unchanged.

```ruby
require "proc_environ"

ENV.mask_proc_data
# SECRET=example becomes SECRET=e*****e in /proc/self/environ

ENV.scrub_proc_data
File.binread("/proc/self/environ").bytes.all?(&:zero?) # => true
ENV["HOME"]                                           # remains available
```

Loading the gem does not change the process environment. Call one of these
methods when your app is ready:

- `ENV.scrub_proc_data` overwrites the whole proc environment with NUL bytes.
- `ENV.mask_proc_data` keeps each variable name and the first and last byte of
  each value. It replaces the bytes between them with `*`.

Values with fewer than three bytes have no middle bytes, so masking leaves them
unchanged.

Both methods return `nil`. They do nothing on non-Linux systems. The gem has no
runtime dependencies. It needs no Linux capabilities.

> [!IMPORTANT]
> A plain `fork` inherits the changed proc data. A new program started with
> `spawn`, `system`, or `exec` gets a fresh proc environment. That program must
> load this gem and call a method for itself.

## How it works

CRuby moves its active environment during startup. Linux still keeps the old
range. Each method reads its limits from `/proc/self/stat`. Before it writes, the
method checks that Ruby no longer uses that range. An unusual Ruby build may
still use it. In that case, the method raises an error and changes nothing.

The proc file keeps its original size after a scrub. Its content becomes NUL
bytes. It does not become a zero-length file. No names or values remain.

The gem changes only the memory shown by `/proc/self/environ`. It does not erase
all copies of a secret. It does not protect against memory leaks, debuggers, or
core dumps.

## Development

```console
ruby -Cext/proc_environ extconf.rb
make -C ext/proc_environ
ruby -Ilib -Iext test/test_proc_environ.rb
```

The Linux end-to-end test runs without additional capabilities.
