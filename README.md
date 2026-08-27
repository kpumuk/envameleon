# proc-environ

`proc-environ` scrubs the initial environment exposed by
`/proc/self/environ`, without changing Ruby's `ENV`.

```ruby
require "proc_environ"

File.binread("/proc/self/environ").bytes.all?(&:zero?) # => true
ENV["HOME"]                                           # remains available
```

The gem has no runtime dependencies, needs no Linux capabilities, and has no
public API. On non-Linux systems, requiring it is a no-op.

## How it works

Linux keeps the initial environment range after CRuby moves its active
environment elsewhere during startup. The extension reads `env_start` and
`env_end` from `/proc/self/stat`, verifies that Ruby's active environment no
longer points into that range, and overwrites the range with NUL bytes. An
unusual Ruby build that still references the original range fails safely.

The proc file retains its original byte length; its contents become all NUL
bytes rather than a zero-length file. No environment names or values remain.

The gem changes only the memory range exported through
`/proc/self/environ`. It does not erase secrets from process memory and does
not protect against memory disclosure, debugging, or core dumps.

## Development

```console
ruby -Cext/proc_environ extconf.rb
make -C ext/proc_environ
ruby -Ilib -Iext test/test_proc_environ.rb
```

The Linux end-to-end test runs without additional capabilities.
