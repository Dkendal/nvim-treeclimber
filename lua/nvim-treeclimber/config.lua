-- This module manages the treeclimber options with the aid of a treeclimber.Opt, which manages the
-- actual option tables (user and default) and supports queries on nested keys.
-- Design Note: The treeclimber-specific logic and data are intentionally kept separate from the Opt
-- manager, which should be comletely generic.

---@class treeclimber.Config
---@field private opt? treeclimber.Opt
local Config = {}

-- The Config instance is a singleton, which holds a single Opt at a time.
local Opt = require"nvim-treeclimber.opt"


-- The default option table
local defaults = {
	ui = {
		-- ** Keymaps **
		---@alias modestr "n"|"v"|"x"|"o"|"s"|"i"|"!"|""
		---@alias lhs string                # Used as <lhs> in call to `vim.keymap.set`
		---@alias treeclimber.KeymapSingle
		---| [(modestr|modestr[]), lhs]     # override the default <lhs> and/or modes
		---@alias treeclimber.KeymapEntry
		---| boolean                        # true to accept default, false to disable
		---| nil                            # accept default (same as omitting command name from table)
		---| lhs                            # override the default <lhs> in default mode(s)
		---| treeclimber.KeymapSingle       # override the default <lhs> and/or modes
		---| treeclimber.KeymapSingle[]     # idem, but allows multiple, mode-specific <lhs>'s
		-- All entries in the default option table must be of this type.
		-- TODO: Consider changing the defaults from <M-...> to <A-...>.
		---@alias treeclimber.KeymapEntryDefCanon
		---| false
		---| treeclimber.KeymapSingle
		---| treeclimber.KeymapSingle[]
		-- All KeymapEntry's are converted to this by successful validation.
		---@alias treeclimber.KeymapEntryCanon
		---| false
		---| treeclimber.KeymapSingle[]
		---@type table<string, treeclimber.KeymapEntryDefCanon>
		keys = {
			show_control_flow = { "n", "<leader>k"},
			select_current_node = {
				-- Note: In normal mode, select_current_node and select_expand are
				-- pretty much equivalent, but the former more accurately reflects
				-- the nature of the operation.
				{"n", "<M-k>"},
				{{ "x", "o" }, "i."}
			},
			select_first_sibling = {{ "n", "x", "o" }, "<M-[>"},
			select_last_sibling = {{ "n", "x", "o" }, "<M-]>"},
			select_top_level = {{ "n", "x", "o" }, "<M-g>"},
			select_forward = {{ "n", "x", "o" }, "<M-l>"},
			select_backward = {{ "n", "x", "o" }, "<M-h>"},
			select_forward_end = {{ "n", "x", "o" }, "<M-e>"},
			select_grow_forward = {{ "n", "x", "o" }, "<M-L>"},
			select_grow_backward = {{ "n", "x", "o" }, "<M-H>"},
			select_expand = {
				{{"x", "o"}, "a."},
				{{"x", "o"}, "<M-k>"}
			},
			select_shrink = {{ "n", "x", "o" }, "<M-j>"},
		},
		-- ** User Commands **
		-- Each entry of the 'cmds table configures the user command for a single treeclimber function.
		---@alias treeclimber.UserCommandEntry
		---| string   # user command name to create for this operation
		---| boolean  # true to enable the default command, false to disable
		-- The default entry is like UserCommandEntry except that true is disallowed, since the
		-- entry must define a default command name.
		---@alias treeclimber.UserCommandEntryCanon string|false
		---@type {[string]: treeclimber.UserCommandEntryCanon}
		cmds = {
			diff_this = "TCDiffThis",
			highlight_external_definitions = "TCHighlightExternalDefinitions",
			show_control_flow = "TCShowControlFlow",
		},
	},
	display = {
		regions = {
			-- ** Highlights **
			---@alias treeclimber.HighlightCallback
			---| fun(o: {normal: HSLUVHighlight, visual: HSLUVHighlight}) : vim.api.keyset.highlight
			---@alias treeclimber.HighlightEntry
			---| vim.api.keyset.highlight       # passed to `nvim_set_hl()`
			---| treeclimber.HighlightCallback  # must return a `vim.api.keyset.highlight`
			---| boolean                        # true for default highlights, false to disable group
			---| nil                            # default highlights
			-- Default canonical: either canonical or will expand to canonical.
			-- Note: User option table may contain the less restrictive HighlightEntry,
			-- but default option table should contain only HighlightEntryDefCanon.
			---@alias treeclimber.HighlightEntryDefCanon
			---| fun(o: {normal: HSLUVHighlight, visual: HSLUVHighlight}) : vim.api.keyset.highlight
			---| vim.api.keyset.highlight
			---| false
			-- All HighlightEntry's converted to this by successful validation.
			---@alias treeclimber.HighlightEntryCanon
			---| vim.api.keyset.highlight
			---| false
			---@type table<string, treeclimber.HighlightEntryDefCanon>
			highlights = {
				-- Note: Overriding bg color of the visual selection doesn't work very well.
				Selection = function(o) return { bg = o.visual.bg.hex } end,
				SiblingStart = false,
				Sibling = function(o) return { bg = o.visual.bg.mix(o.normal.bg, 50).hex } end,
				Parent = function(o) return { bg = o.visual.bg.mix(o.normal.bg, 80).hex } end,
				ParentStart = false,
			},
			-- `true` to cause attributes like bold and italic to "bleed through" from Parent
			-- to Siblings.
			inherit_attrs = true,
			-- `true` to replace default 'highlights' with user overrides, false or nil to merge
			replace_defaults = false,
		},
	},
	traversal = {
	},
}

-- Define some helpers.
-- Return true iff input string is a mode string that could be used in a call to vim.keymap.set().
function Config.is_mode(x)
	return type(x) == "string" and x:match("^[nvxosi!]?$")
end

-- Return true iff input is an array of mode strings that could be used in a call to vim.keymap.set().
function Config.is_mode_array(x)
	return vim.islist(x) and vim.iter(x):all(function(x_) return Config.is_mode(x_) end)
end

-- Return true if input is of type treeclimber.KeymapSingle
-- TODO: Consider adding an is_loose_keymap_entry function or somesuch, which doesn't validate,
-- modes.
-- Rationale: Could be used to improve error diagnostics.
function Config.is_keymap_single(x)
	return vim.islist(x) and #x == 2 and (Config.is_mode(x[1]) or Config.is_mode_array(x[1]))
		and type(x[2]) == "string"
end

-- Return true if input is an array of treeclimber.KeymapSingle
function Config.is_keymap_entry_array(x)
	return vim.islist(x) and vim.iter(x):all(function (x_) return Config.is_keymap_single(x_) end)
end

-- Create a new Config object representing the default option table.
-- Note: The first call to require('treeclimber.config') constructs a singleton Config object with
-- an Opt managing pure defaults (since user could not have called setup() at that point). If a
-- subsequent user call to setup() provides an option table override, we'll construct a new Opt
-- encapsulating it; otherwise, we'll just keep the existing one.
-- Rationale: This approach ensures things will work even if user skips call to setup() and calls
-- (eg) setup_keymaps() manually.
function Config:new()
	local obj = {
		-- Start with a default Opt, which may be overridden later with setup().
		opt = Opt:new(defaults)
	}
	self.__index = self
	return setmetatable(obj, self)
end

-- Note: Config:new() instantiates an Opt representing default configuration. That instance is
-- perfectly capable of being used by Treeclimber if this function is never called (or if it's
-- called with no option table).
---@param opt? table
function Config:setup(opt)
	if opt then
		self.opt = Opt:new(defaults, opt)
	end
end

-- Get default option value for fully-qualified name.
---@param fqn string[]|string
function Config:get_default(fqn)
	return self.opt:get(fqn, {want_default = true})
end

---@param fqn string[]|string
function Config:get(fqn)
	return self.opt:get(fqn)
end

-- Create and return singleton Config for treeclimber.
-- Note: The default Opt it contains will be replaced if the setup() method is subsequently called
-- with a user override.
return Config:new()
