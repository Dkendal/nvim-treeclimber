local M = {}
local tc = require("nvim-treeclimber.api")
local Config = require('nvim-treeclimber.config')
local Util = require('nvim-treeclimber.util')
local Hi = require("nvim-treeclimber.hi")

-- Re-export nvim-treeclimber.api
for k, v in pairs(tc) do
	M[k] = v
end

-- Define some aliases for functions whose names don't match their behavior.
-- Rationale: The descriptions in the README say "select first/last sibling"; however, for
-- backwards-compatibility reasons, we still need to support the old names.
-- Design Decision: Not necessary to support the old names as keys in the new option table, since
-- users who create an option table will see only the new names in the documentation.
M.select_siblings_backward = M.select_first_sibling
M.select_siblings_forward = M.select_last_sibling

-- Keymap descriptions (used in call to vim.keymap.set)
local default_keymap_descriptions = {
	show_control_flow = "",
	select_current_node = "Treeclimber select current node",
	select_forward_end = "Treeclimber select and move to the end of the node, or the end of the next node",
	select_first_sibling = "Treeclimber select first sibling node",
	select_last_sibling = "Treeclimber select last sibling node",
	select_top_level = "Treeclimber select the top level node from the current position",
	select_backward = "Treeclimber select previous node",
	select_shrink = "Treeclimber select child node",
	select_expand = "Treeclimber select parent node",
	select_forward = "Treeclimber select the next node",
	select_grow_forward = "Treeclimber add the next node to the selection",
	select_grow_backward = "Treeclimber add the next node to the selection",
}

-- User command descriptions (used in call to nvim_create_user_command)
local default_command_descriptions = {
	diff_this = "Diff two visual selections based on their AST difference.",
	highlight_external_definitions = "WIP",
	show_control_flow = "Populate the quick fix with all branches required to reach the current node.",
}

-- Validate the input KeymapEntry and return one of the following as the first return value:
--   * a KeymapEntryCanon to use with vim.keymap.set(), taking defaults into account if applicable
--   * false if the keymap should be disabled
--   * nil if the entry is invalid.
---@param ut treeclimber.KeymapEntry|nil The user entry to validate (or nil to use default)
---@param dt treeclimber.KeymapEntryCanon The corresponding entry from defaults in canonical form
---@return treeclimber.KeymapEntryCanon|nil # Keymap entry suitable for use with vim.keymap.set() 
---                                         # false if disabled
---                                         # nil on error
---@return string|nil                       # error msg if first return value is nil
local function parse_keymap_entry(ut, dt)
	if ut == nil then
		-- Note: This is not considered error, so return default (possibly false).
		return dt
	end
	local utyp = type(ut)
	if utyp == "boolean" or utyp == "string" then
		if dt == false then
			return nil, "No default keymap defined for this function and user override incomplete"
		end
		if utyp == "boolean" then
			-- Note: Explicit false disables the map without error or warning.
			return ut and dt or false
		elseif utyp == "string" then
			-- Use default entry with overridden lhs.
			-- TODO: Warn if there really are multiple mode entries?
			return vim.iter(dt):map(function (x) return {x[1], ut} end):totable()
		end
	end
	-- At this point, the only valid possibility is a user-supplied table that can be converted
	-- to canonical form.
	if Config.is_keymap_single(ut) then
		-- Return canonical form.
		return {ut}
	elseif Config.is_keymap_entry_array(ut) then
		return ut
	end
	-- Invalid format!
	return nil
end

function M.setup_keymaps()
	---@type table<string, treeclimber.KeymapEntry>|boolean
	local ukeys = Config:get("ui.keys")
	---@type table<string, treeclimber.KeymapEntryCanon> # Default keys
	local dkeys = Config:get_default("ui.keys")
	-- User can set entire keys option to boolean to enable/disable *all* default maps.
	if type(ukeys) == "boolean" then
		if not ukeys then
			-- User has disabled keymaps! Nothing do do...
			return
		end
		-- User has requested defaults, either explicitly or with empty table.
		ukeys = dkeys
	elseif type(ukeys) == "table" then
		-- Make sure it's the right kind of table.
		if vim.isarray(ukeys) and not vim.tbl_isempty(ukeys) then
			Util.error("Ignoring invalid 'keys' option: %s", vim.inspect(ukeys))
			ukeys = dkeys
		else
			local unk_keys = vim.iter(vim.tbl_keys(ukeys))
				:filter(function(x) return dkeys[x] == nil end)
				:join(", ")
			if #unk_keys > 0 then
				-- Design Decision: Fall through to use any valid keys.
				Util.error("Ignoring the following invalid keys in the 'keys' option: %s", unk_keys)
			end
		end
	end
	-- Loop over default keymap entries.
	for k, dv in pairs(dkeys) do
		---@type treeclimber.KeymapEntryCanon
		local cfg
		-- Canonicalize default entry.
		if Config.is_keymap_single(dv) then
			---@cast dv treeclimber.KeymapSingle
			dv = {dv}
		elseif type(dv) == 'table' then
			-- Make sure it's in canonical form.
			assert(vim.islist(dv) and
				vim.iter(dv):all(function (x) return Config.is_keymap_single(x) end),
				string.format("Internal error: invalid entry in default `keys':"
				.. " %s => %s", k, vim.inspect(dv)))
		end
		if ukeys == dkeys then
			-- No need to validate default entry
			---@cast dv treeclimber.KeymapEntryCanon
			cfg = dv
		else
			local uv = ukeys[k]
			-- Get valid KeymapEntryCanon for the current keymap.
			---@type treeclimber.KeymapEntryCanon|nil|false
			local cfg_, err = parse_keymap_entry(uv, dv)
			if cfg_ == nil then
				Util.error("Ignoring invalid keymap entry for %s: %s%s",
					k, vim.inspect(uv), err and " due to error `" .. err .. "'" or "")
				---@cast dv treeclimber.KeymapEntryCanon
				cfg = dv
			else
				-- Use value returned by parse_keymap_entry (possibly false).
				---@cast cfg_ treeclimber.KeymapEntryCanon|false
				cfg = cfg_
			end
		end
		assert(cfg == false or cfg, "Internal error: No fallback keymap entry for " .. k)
		-- One or more keymaps (corresponding to different mode sets) need to be created for
		-- the current command.
		if cfg and type(cfg) == "table" then
			-- Loop over the mode sets.
			for _, c in ipairs(cfg) do
				vim.keymap.set(c[1], c[2], tc[k], { desc = default_keymap_descriptions[k] })
			end
		end
	end
end

function M.setup_user_commands()
	---@type table<string, treeclimber.UserCommandEntry>
	local ucmds = Config:get("ui.cmds")
	---@type table<string, treeclimber.UserCommandEntryCanon> # Default keys
	local dcmds = Config:get_default("ui.cmds")
	-- User can set entire cmds option to boolean to enable/disable *all* default user commands.
	if type(ucmds) == "boolean" then
		if not ucmds then
			-- User has disabled keymaps! Nothing do do...
			return
		end
		-- User has requested defaults.
		ucmds = dcmds
	elseif type(ucmds) == "table" then
		-- Make sure it's the right kind of table.
		if vim.isarray(ucmds) and not vim.tbl_isempty(ucmds) then
			Util.error("Ignoring invalid 'cmds' option: %s", vim.inspect(ucmds))
			ucmds = dcmds
		else
			-- Make sure all keys are valid.
			local unk_cmds = vim.iter(vim.tbl_keys(ucmds))
				:filter(function(x) return dcmds[x] == nil end)
				:join(", ")
			if #unk_cmds > 0 then
				-- Design Decision: Fall through to use any valid keys.
				Util.error("Ignoring the following invalid keys in the 'cmds' option: %s", unk_cmds)
			end
		end
	else
		Util.error("Ignoring invalid 'cmds' option: %s", vim.inspect(ucmds))
		ucmds = dcmds
	end

	-- Loop over default user command entries.
	for k, dv in pairs(dcmds) do
		---@type treeclimber.UserCommandEntryCanon
		local cfg
		assert(type(dv) == 'string' or dv == false,
			string.format("Internal error: Invalid default user command entry for %s: %s",
			k, vim.inspect(dv)))
		-- Note: If using all defaults, ucmds may refer to dcmds at this point.
		local uv = ucmds[k]
		if type(uv) ~= 'boolean' and type(uv) ~= 'string' and uv ~= nil then
			-- Type of user entry is invalid.
			Util.error("Ignoring invalid user command entry for %s: %s",
				k, vim.inspect(uv))
			cfg = dv
		else
			-- Overall form of user entry appears valid.
			if type(uv) == 'string' then
				if string.match(uv, [[^%u[%w_]+$]]) then
					cfg = uv
				else
					Util.error("Ignoring invalid user command name: %s", uv)
					cfg = dv
				end
			elseif uv == true or uv == nil then
				-- Accept default.
				cfg = dv
			else
				cfg = false -- disable
			end
		end

		-- Note: This test (as opposed to simpler `if cfg') is necessitated by what appears
		-- to be a LuaLS bug: type system should see that cfg can't be true, but thinks it
		-- can be.
		if type(cfg) == 'string' then
			-- Create user command.
			vim.api.nvim_create_user_command(cfg, tc[k], {
				force = true, range = true, desc = default_command_descriptions[k]
			})
		end
	end
end

---@param uhl treeclimber.HighlightEntry
---@param dhl treeclimber.HighlightEntryDefCanon
---@param normal HSLUVHighlight
---@param visual HSLUVHighlight
---@param replace_defaults boolean Whether default hl is replaced by or merged with user override
---@return treeclimber.HighlightEntryCanon? cfg Valid hl or false to disable or nil on error
---@return treeclimber.HighlightEntryCanon? fallback The fallback hl to use on error
---@return string|nil err An error message in case of fallback
local function parse_highlight_entry(uhl, dhl, normal, visual, replace_defaults)
	if type(dhl) == "function" then
		---@cast dhl vim.api.keyset.highlight
		dhl = dhl({normal = normal, visual = visual})
	end
	if uhl == true or uhl == nil then
		return dhl -- use default
	elseif uhl == false then
		-- Disable this one.
		return false
	end
	-- User provided some sort of override requiring validation (possibly after expansion).
	if type(uhl) == "function" then
		uhl = uhl({normal = normal, visual = visual})
	end
	-- Validate the user highlight entry by using in protected call to nvim_set_hl().
	local validation_ns = vim.api.nvim_create_namespace("treeclimber.validation")
	local valid, _ = pcall(vim.api.nvim_set_hl, validation_ns, "ValidationGroup", uhl)
	if not valid then
		return nil, dhl, string.format("Invalid user highlight entry: %s", vim.inspect(uhl))
	end
	-- Now that we know user config is valid, merge it with default unless default is `false` or
	-- the 'replace_defaults' option is set, in which case, we use user highlight as is.
	-- Note: A default of false is functionally equivalent to {}; default should never be `true`.
	assert(dhl == false or type(dhl) == 'table', "Internal error: Invalid default highlight: %s", vim.inspect(dhl))
	return type(dhl) == 'table' and not replace_defaults
		and vim.tbl_deep_extend('force', dhl, uhl) or uhl
end

function M.setup_highlight()
	-- Must run after colorscheme or TermOpen to ensure that terminal_colors are available

	local Normal = Hi.get_hl("Normal", { follow = true })
	assert(not vim.tbl_isempty(Normal), "hi Normal not found")
	local normal = Hi.HSLUVHighlight:new(Normal)

	local Visual = Hi.get_hl("Visual", { follow = true })
	assert(not vim.tbl_isempty(Visual), "hi Visual not found")
	local visual = Hi.HSLUVHighlight:new(Visual)

	local defaults = Config:get_default("display.regions.highlights")
	-- Get user overrides.
	local overrides = Config:get("display.regions.highlights")
	-- Determine whether default highlights are replace by or merged with user overrides.
	local replace_defaults = Config:get("display.regions.replace_defaults")
	-- Skip if entire "highlights" key is explicit false.
	if type(overrides) ~= "boolean" or overrides then
		if overrides ~= nil and (type(overrides) ~= "table" or vim.islist(overrides)) then
			-- Overall form of display.regions.highlight is invalid.
			Util.error("Ignoring invalid 'highlights' option: expected dictionary")
			overrides = nil
		end

		-- Loop over keys in the default table.
		for k, dv in pairs(defaults) do
			-- Note: luals requires an extra nil-check on overrides for some reason.
			local uv = (overrides == true or overrides == nil) and dv or overrides and overrides[k]
			-- Note: uv can be explicit false (to disable highlight) at this point.
			if uv then
				-- Validate and merge to get the vim.api.keyset.highlight to use.
				local cfg, fallback, err = parse_highlight_entry(
					uv, dv, normal, visual, replace_defaults)
				-- Note: If cfg is explicit false, just skip.
				if cfg or cfg == nil then
					if cfg == nil then
						-- Warn and use fallback.
						Util.error(string.format(
							"Ignoring invalid user-provided highlight for %s"
							.. ": %s%s", k, vim.inspect(uv),
							err and ": " .. err or ""))
					end
					assert(cfg or fallback, "Internal error: Fallback highlight for " .. k .. " is nil")
					vim.api.nvim_set_hl(0, k, cfg or fallback or {})
				end
			end
		end
	end
end

function M.setup_augroups()
	local group = vim.api.nvim_create_augroup("nvim-treeclimber-colorscheme", { clear = true })

	vim.api.nvim_create_autocmd({ "Colorscheme" }, {
		group = group,
		pattern = "*",
		callback = function()
			M.setup_highlight()
		end,
	})
end

---@param opt table?
function M.setup(opt)
	if opt then
		-- If user provided an option table, persist it; otherwise, stick with defaults.
		Config:setup(opt)
	end
	M.setup_keymaps()
	M.setup_user_commands()
	M.setup_augroups()
end

return M
