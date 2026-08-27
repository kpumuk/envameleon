# proc-environ

`proc-environ` empties `/proc/self/environ` when it is required, without
changing Ruby's `ENV`.

```ruby
require "proc_environ"

File.binread("/proc/self/environ") # => ""
ENV["HOME"]                        # remains available
```

The gem has no runtime dependencies and no public API. On non-Linux systems,
requiring it is a no-op.

## Linux capability

Linux requires `CAP_SYS_RESOURCE` for `PR_SET_MM`. Without that capability,
requiring the gem raises `Errno::EPERM`; it never silently leaves the
environment exposed.

For a container, grant only that capability:

```console
docker run --cap-add SYS_RESOURCE ...
```

The gem changes only the memory range exported through
`/proc/self/environ`. It does not erase secrets from process memory and does
not protect against memory disclosure, debugging, or core dumps.

## Development

```console
ruby -Cext/proc_environ extconf.rb
make -C ext/proc_environ
ruby -Ilib -Iext test/test_proc_environ.rb
```

The Linux end-to-end test must run with `CAP_SYS_RESOURCE`.
