local M = {}

local tc = require("nvim-treeclimber.api")

-- Re-export nvim-treeclimber.api
for k, v in pairs(tc) do
	M[k] = v
end

function M.setup(_)
	local function setup_hi()
		local hi = require("nvim-treeclimber.hi")
		local term_colors = hi.ansi_colors()
		local hi_normal = hi.get_hl("Normal", { follow = true })

		hi_normal = hi_normal and hi.HSLUVHighlight:new(hi_normal) or { bg = term_colors[0], fg = term_colors[1] }

		if vim.tbl_isempty(hi_normal) then
			return
		end

		local bg = hi_normal.bg
		local fg = hi_normal.fg

		local dim = bg.mix(fg, 20)

		vim.api.nvim_set_hl(0, "TreeClimberHighlight", { background = dim.hex })

		vim.api.nvim_set_hl(0, "TreeClimberSiblingBoundary", { background = term_colors[5].hex })

		vim.api.nvim_set_hl(0, "TreeClimberSibling", { background = term_colors[5].mix(bg, 40).hex, bold = true })

		vim.api.nvim_set_hl(0, "TreeClimberParent", { background = bg.mix(fg, 2).hex })

		vim.api.nvim_set_hl(0, "TreeClimberParentStart", { background = term_colors[4].mix(bg, 10).hex, bold = true })
	end

	setup_hi()

	local group = vim.api.nvim_create_augroup("nvim-treeclimber-colorscheme", { clear = true })

	vim.api.nvim_create_autocmd({ "Colorscheme" }, {
		group = group,
		pattern = "*",
		callback = function()
			setup_hi()
		end,
	})

	vim.keymap.set("n", "<leader>k", tc.show_control_flow, {})

	vim.keymap.set({ "x", "o" }, "i.", tc.select_current_node, { desc = "select current node" })

	vim.keymap.set({ "x", "o" }, "a.", tc.select_expand, { desc = "select parent node" })

	vim.keymap.set(
		{ "n", "x", "o" },
		"<M-e>",
		tc.select_forward_end,
		{ desc = "select and move to the end of the node, or the end of the next node" }
	)

	vim.keymap.set(
		{ "n", "x", "o" },
		"<M-b>",
		tc.select_backward,
		{ desc = "select and move to the begining of the node, or the beginning of the next node" }
	)

	vim.keymap.set({ "n", "x", "o" }, "<M-[>", tc.select_siblings_backward, {})

	vim.keymap.set({ "n", "x", "o" }, "<M-]>", tc.select_siblings_forward, {})

	vim.keymap.set(
		{ "n", "x", "o" },
		"<M-g>",
		tc.select_top_level,
		{ desc = "select the top level node from the current position" }
	)

	vim.keymap.set({ "n", "x", "o" }, "<M-h>", tc.select_backward, { desc = "select previous node" })

	vim.keymap.set({ "n", "x", "o" }, "<M-j>", tc.select_shrink, { desc = "select child node" })

	vim.keymap.set({ "n", "x", "o" }, "<M-k>", tc.select_expand, { desc = "select parent node" })

	vim.keymap.set({ "n", "x", "o" }, "<M-l>", tc.select_forward, { desc = "select the next node" })

	vim.keymap.set({ "n", "x", "o" }, "<M-L>", tc.select_grow_forward, { desc = "Add the next node to the selection" })

	vim.keymap.set({ "n", "x", "o" }, "<M-H>", tc.select_grow_backward, { desc = "Add the next node to the selection" })

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

return M
