# frozen_string_literal: true

require "mkmf"

append_cflags %w[
  -Wall
  -Wextra
  -Wformat=2
  -Werror=format-security
  -Werror=implicit-function-declaration
  -fstack-protector-strong
  -fvisibility=hidden
]

if RUBY_PLATFORM.include?("linux")
  append_cflags "-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"

  append_ldflags %w[
    -Wl,-z,noexecstack
    -Wl,-z,now
    -Wl,-z,relro
  ]
end

create_makefile("envameleon/envameleon")
