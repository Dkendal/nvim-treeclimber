-- This module may be used to manage and query a hierarchical tree of options.
-- The constructor takes a default option table and, optionally, a sparse table of overrides
-- (typically a user option table). Query methods accept dot-separated name strings corresponding to
-- nested keys, and return the corresponding values, with configurable fallback to defaults, error
-- handling, table repair, etc.

---@class treeclimber.Opt
---@field private defaults table<string,any>
---@field private current? table<string,any> # User option table (if provided)
local Opt = {}

local Util = require('nvim-treeclimber.util')

---Parse and validate a fully-qualified option name, specified in string or table form, returning
---the table form.
---Note: Because this function is for internal use only, all option names are expected to be valid,
---and we simply assert on validity.
---@package
---@param fqn string|string[] # Option name as either a dot-separated string or a table of name components
---@return string[]           # Table of option name components
function Opt:parse_fqn(fqn)
	if type(fqn) == "string" then
		fqn = vim.split(fqn, "[.]")
	end
	-- Verify that name components all look like normal keys.
	assert(vim.iter(fqn):all(function(x) return x:match("[%w_]+") end),
		"Bad fully-qualified option name: " .. vim.inspect(fqn))
	return fqn
end

---@package
---@param opt? table Table to override defaults
function Opt:merge_current(opt)
	-- TODO: Consider skipping the merge if opt is nil.
	self.current = vim.tbl_deep_extend('force', self.defaults, opt or {})
end

---@param defaults table
---@param opt? table
function Opt:new(defaults, opt)
	-- Note: current may be nil.
	local obj = { defaults = defaults }
	self.__index = self
	setmetatable(obj, {__index = self})
	-- Defer override of current until we have opt.
	-- Rationale: There's no point in merging an empty table.
	if opt then
		obj:merge_current(opt)
	end
	return obj
end

-- TODO: Perhaps rename to set()
---@param fqn string|string[]
---@param value any
function Opt:__newindex(fqn, value)
	local keyarr = self:parse_fqn(fqn)
	if not keyarr or #keyarr == 0 then
		-- Shouldn't happen, but nothing to do.
		return
	end
	-- Make sure we have an option table to modify.
	if not self.current then
		self:merge_current()
	end
	-- Ensure a path exists from the option table root to the descendant node at which we're
	-- about to add a leaf, creating intervening nodes as necessary.
	local last = vim.iter(keyarr)
		:take(#keyarr - 1)
		:fold(self.current, function (acc, k)
			if acc[k] == nil then
				acc[k] = {}
			end
			return acc[k]
		end)
	-- Add the leaf.
	last[keyarr[#keyarr]] = value
end


-- Get value (either overridden or default) corresponding to the fully-qualified name <fqn>.
-- If `current` is nil, we're managing pure (non-overridden) defaults, which means failure to find
-- the key implies internal error (bad default option table). If a user override has been specified,
-- it will have been merged with the default option table; thus, the <fqn> should be found unless
-- an invalid user option table has broken the merge: e.g.,
-- A user table of { foo = 42 } would prevent "foo.bar" from being found, even though it exists in
-- the default table. The optional `QueryOpt` object may be used to customize lookup behavior (e.g.,
-- handling of missing keys).
---@class treeclimber.opt.QueryOpt
---@field notify? "warning"|"error"|"exception"|false  # how to handle missing key, false to disable notification
---@field want_default? boolean           # true to ignore user override table
---@field repair? boolean                 # true to repair missing key from defaults (to
---                                       # prevent repeat warnings)
---@field fallback? boolean               # true to fallback to default
---@param fqn string|string[]             # Fully-qualified option name string, either as array of
---                                       # components or dot-separated string
---@param default? any
---@return any                            # the requested option value (possibly a fallback)
function Opt:get(fqn, cfg, default)
	-- Merge any caller-specified options with defaults.
	cfg = vim.tbl_deep_extend("force",
		{notify = "error", want_default = false, repair = true, fallback = true}, cfg or {})
	-- TODO: Consider validating the booleans, though only internal error could result in
	-- invalid format.
	assert(not cfg.notify or vim.list_contains({"warning", "error", "assert"}, cfg.notify),
		"Invalid value provided for missing.notify: " .. vim.inspect(cfg.notify))
	-- Subsequent logic needs an options table, either user's current override (if one exists
	-- and defaults not explicitly requested) or the defaults
	local opt = not cfg.want_default and self.current or self.defaults
	-- Input fqn can be in either of two forms: make sure we have it in valid array form.
	local keyarr = self:parse_fqn(fqn)
	-- Validate that name components all look like normal keys.
	assert(vim.iter(keyarr):all(function(x) return x:match("[%w_]+") end),
		"Bad fully-qualified option name: " .. fqn)
	local v = vim.tbl_get(opt, unpack(keyarr))
	if opt.notify == "assert" then
		assert(v ~= nil, "Requested option not found: %s", fqn)
	end
	if v == nil then
		-- Option not found
		-- This should never happen if user hasn't overridden config.
		assert(opt ~= self.defaults, "Internal error: missing default option key: " .. fqn)
		-- Invalid user override must have clobbered something.
		if opt.notify then
			Util.notify(opt.notify, "Requested option not defined: %s", fqn)
		end
		-- Has caller supplied a default? If so, return it, without regard to missing.fallback.
		local dvalue
		if default ~= nil then
			dvalue = default
		elseif opt.fallback then
			-- Return plugin-defined default (which should definitely exist).
			dvalue = vim.tbl_get(self.defaults, unpack(keyarr))
			assert(dvalue ~= nil, "Internal error: requested option has no fallback: " .. fqn)
		end
		if opt.repair and dvalue ~= nil then
			-- We have a fallback and repair is enabled.
			-- Assumption: An earlier assert() ensures we arrive here only when user has
			-- overridden defaults.
			self[keyarr] = dvalue
		end
		v = dvalue
	end
	return v
end

return Opt
