local M = {}

local tc = require("nvim-treeclimber.api")

-- Re-export nvim-treeclimber.api
for k, v in pairs(tc) do
	M[k] = v
end

function M.setup_keymaps()
	vim.keymap.set("n", "<Plug>(treeclimber-show-control-flow)", tc.show_control_flow, {})

	vim.keymap.set({ "x", "o" }, "<Plug>(treeclimber-select-current-node)", tc.select_current_node, { desc = "select current node" })

	vim.keymap.set({ "x", "o" }, "<Plug>(treeclimber-select-expand)", tc.select_expand, { desc = "select parent node" })

	vim.keymap.set(
		{ "n", "x", "o" },
		"<Plug>(treeclimber-select-forward-end)",
		tc.select_forward_end,
		{ desc = "select and move to the end of the node, or the end of the next node" }
	)

	vim.keymap.set(
		{ "n", "x", "o" },
		"<Plug>(treeclimber-select-backward)",
		tc.select_backward,
		{ desc = "select and move to the begining of the node, or the beginning of the next node" }
	)

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-siblings-backward)", tc.select_siblings_backward, {})

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-siblings-forward)", tc.select_siblings_forward, {})

	vim.keymap.set(
		{ "n", "x", "o" },
		"<Plug>(treeclimber-select-top-level)",
		tc.select_top_level,
		{ desc = "select the top level node from the current position" }
	)

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-previous)", tc.select_backward, { desc = "select previous node" })

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-shrink)", tc.select_shrink, { desc = "select child node" })

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-parent)", tc.select_expand, { desc = "select parent node" })

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-next)", tc.select_forward, { desc = "select the next node" })

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-grow-forward)", tc.select_grow_forward, { desc = "Add the next node to the selection" })

	vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-grow-backward)", tc.select_grow_backward, { desc = "Add the next node to the selection" })
end

function M.setup_user_commands()
	vim.api.nvim_create_user_command("TCDiffThis", tc.diff_this, { force = true, range = true, desc = "" })

	vim.api.nvim_create_user_command(
		"TCHighlightExternalDefinitions",
		tc.highlight_external_definitions,
		{ force = true, range = true, desc = "WIP" }
	)

	vim.api.nvim_create_user_command("TCShowControlFlow", tc.show_control_flow, {
		force = true,
		range = true,
		desc = "Populate the quick fix with all branches required to reach the current node",
	})
end

function M.setup_highlight()
	-- Must run after colorscheme or TermOpen to ensure that terminal_colors are available
	local hi = require("nvim-treeclimber.hi")

	local Normal = hi.get_hl("Normal", { follow = true })
	assert(not vim.tbl_isempty(Normal), "hi Normal not found")
	local normal = hi.HSLUVHighlight:new(Normal)

	local Visual = hi.get_hl("Visual", { follow = true })
	assert(not vim.tbl_isempty(Visual), "hi Visual not found")
	local visual = hi.HSLUVHighlight:new(Visual)

	vim.api.nvim_set_hl(0, "TreeClimberHighlight", { background = visual.bg.hex })
	vim.api.nvim_set_hl(0, "TreeClimberSiblingBoundary", { background = visual.bg.mix(normal.bg, 50).hex })
	vim.api.nvim_set_hl(0, "TreeClimberSibling", { background = visual.bg.mix(normal.bg, 50).hex })
	vim.api.nvim_set_hl(0, "TreeClimberParent", { background = visual.bg.mix(normal.bg, 50).hex })
	vim.api.nvim_set_hl(0, "TreeClimberParentStart", { background = visual.bg.mix(normal.bg, 50).hex })
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

function M.setup()
	M.setup_keymaps()
	M.setup_user_commands()
	M.setup_augroups()
end

return M
