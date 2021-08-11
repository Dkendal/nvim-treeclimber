MAKEFLAGS=-j 10

fennel_paths := fnl/?.fnl
lua_paths := lua/?.lua /usr/share/nvim/runtime/lua/?.lua

FNL_FLAGS =
FNL = fennel
FNL += $(patsubst %, --add-fennel-path %, $(fennel_paths))
FNL += $(patsubst %, --add-package-path %, $(lua_paths))
FNL += $(FNL_FLAGS)
FNL += --compile

macro_files := %/macros.fnl

fnl_files := $(wildcard fnl/*.fnl fnl/**/*.fnl)
fnl_compiled_files := $(filter-out $(macro_files), $(fnl_files))
lua_files := $(patsubst fnl/%.fnl, lua/%.lua, $(fnl_compiled_files))
lua_files := $(filter-out $(macro_files), $(lua_files))

reset := \e[0;0m
blue := \e[1;34m

all:: $(dir lua_files) $(lua_files)

@PHONY:
clean::
	rm -rf $(lua_files)

lua/%.lua:: fnl/%.fnl
	@echo "${blue}${@}${reset}"
	mkdir -p $(dir $@)
	$(FNL) $< > $@ || rm $@

@PHONY:
list-src:
	@echo $(fnl_compiled_files)

@PHONY:
list-out:
	@echo $(lua_files)

% ::
	@echo $@
