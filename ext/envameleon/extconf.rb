# frozen_string_literal: true

require "mkmf"

%w[
  -Wall
  -Wextra
  -Wformat=2
  -Werror=format-security
  -Werror=implicit-function-declaration
  -fstack-protector-strong
  -fvisibility=hidden
].each do |flag|
  $CFLAGS << " #{flag}" if try_cflags(flag)
end

if RUBY_PLATFORM.include?("linux")
  fortify = "-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"
  $CFLAGS << " #{fortify}" if try_cflags(fortify)

  %w[
    -Wl,-z,noexecstack
    -Wl,-z,now
    -Wl,-z,relro
  ].each do |flag|
    $LDFLAGS << " #{flag}" if try_ldflags(flag)
  end
end

create_makefile("envameleon/envameleon")
