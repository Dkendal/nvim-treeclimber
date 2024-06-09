#!/usr/bin/env bash

mkdir -p cover

rm -rf cover/*

set -euo pipefail

export LUA_PATH='/Users/dylan/src/dkendal/nvim-treeclimber/lua_modules/share/lua/5.1/?.lua;/Users/dylan/src/dkendal/nvim-treeclimber/lua_modules/share/lua/5.1/?/init.lua;/Users/dylan/.local/share/mise/downloads/lua/5.1.5/lua-5.1.5/luarocks-3.11.0/src/?.lua;./?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;;/Users/dylan/.luarocks/share/lua/5.1/?.lua;/Users/dylan/.luarocks/share/lua/5.1/?/init.lua;/Users/dylan/.local/share/mise/installs/lua/5.1.5/luarocks/share/lua/5.1/?.lua;/Users/dylan/.local/share/mise/installs/lua/5.1.5/luarocks/share/lua/5.1/?/init.lua'
export LUA_CPATH='/Users/dylan/src/dkendal/nvim-treeclimber/lua_modules/lib/lua/5.1/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/Users/dylan/.luarocks/lib/lua/5.1/?.so;/Users/dylan/.local/share/mise/installs/lua/5.1.5/luarocks/lib/lua/5.1/?.so'

export XDG_CONFIG_HOME='.tests/xdg/config/'
export XDG_STATE_HOME='.tests/xdg/local/state/'
export XDG_DATA_HOME='.tests/xdg/local/share/'

nvim --cmd 'set loadplugins' -u ./tests/init.lua -l "$@"

exit_code="$?"

lua ./tests/console_reporter.lua ./cover/report.out "$@"

exit "$exit_code"
