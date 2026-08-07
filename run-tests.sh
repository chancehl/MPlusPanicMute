#!/usr/bin/env sh
# Run the addon's test suite. Any arguments are passed through to busted,
# e.g. ./run-tests.sh spec/mute_group_spec.lua --verbose
set -e

# The specs loadfile("MPlusPanicMute.lua") relative to the working directory.
cd "$(dirname "$0")"

BUSTED="${BUSTED:-$HOME/.luarocks/bin/busted}"

if [ ! -x "$BUSTED" ]; then
  echo "busted not found at $BUSTED" >&2
  echo "" >&2
  echo "Install the toolchain (LuaJIT matches the game's Lua 5.1):" >&2
  echo "  brew install luajit luarocks" >&2
  echo "  luarocks --lua-version=5.1 --lua-dir=\$(brew --prefix luajit) --local install busted" >&2
  exit 1
fi

exec "$BUSTED" "$@"
