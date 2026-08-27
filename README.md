# proc-environ

`proc-environ` can hide, mask, or drop the initial environment in
`/proc/self/environ`. It leaves Ruby's `ENV` unchanged.

```ruby
require "proc_environ"

ENV.mask_proc_data
# SECRET=example becomes SECRET=e*****e in /proc/self/environ

ENV.scrub_proc_data
File.binread("/proc/self/environ").bytes.all?(&:zero?) # => true
ENV["HOME"]                                           # remains available

ENV.drop_proc_data # requires CAP_SYS_RESOURCE
File.empty?("/proc/self/environ")                     # => true
```

A `require` call does not change the process environment. Call one of these
methods when your app is ready:

- `ENV.scrub_proc_data` will fill the whole proc environment with NUL bytes.
- `ENV.mask_proc_data` will keep each variable name and the first and last byte
  of each value. It will replace the bytes between them with `*`.
- `ENV.drop_proc_data` will make the proc file zero bytes long. It needs the Linux
  `CAP_SYS_RESOURCE` capability.

Values with fewer than three bytes have no middle bytes, so masking leaves them
unchanged.

All methods return `nil`. They do nothing on non-Linux systems. The gem does not
use other gems. Scrub and mask need no Linux capabilities.

> [!IMPORTANT]
> A plain `fork` gets the changed proc data for all three methods. A new
> program started with `spawn`, `system`, or `exec` gets a fresh proc
> environment. That program must load this gem and call a method for itself.

## How it works

CRuby moves its active environment during startup. Linux still keeps the old
range. Scrubbing and masking read its limits from `/proc/self/stat`. Before they
write, they check that Ruby no longer uses that range. An unusual Ruby build may
still use it. In that case, the method raises an error and changes nothing.

The proc file keeps its original size after a scrub. Its content becomes NUL
bytes. It does not become a zero-length file. No names or values remain.

Dropping uses `PR_SET_MM_ENV_END` to move the end of the kernel's proc view to
its start. This makes the proc file empty but does not overwrite its old memory.
Linux requires `CAP_SYS_RESOURCE` for this operation. You can use this
capability for much more than this gem.

The gem changes only the memory shown by `/proc/self/environ`. It does not erase
all copies of a secret. It does not protect against memory leaks, debuggers, or
core dumps.

## Development

```console
ruby -Cext/proc_environ extconf.rb
make -C ext/proc_environ
ruby -Ilib -Iext test/test_proc_environ.rb
```

On Linux, the scrub and mask tests need no extra capability. The drop test runs
when `CAP_SYS_RESOURCE` is available. If it is not, the test is omitted.
