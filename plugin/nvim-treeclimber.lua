-- Keymaps
vim.keymap.set("n", "<Plug>(treeclimber-show-control-flow)", function()
	require("nvim-treeclimber.api").show_control_flow()
end, {})

vim.keymap.set({ "x", "o" }, "<Plug>(treeclimber-select-current-node)", function()
	require("nvim-treeclimber.api").select_current_node()
end, { desc = "select current node" })

vim.keymap.set({ "x", "o" }, "<Plug>(treeclimber-select-expand)", function()
	require("nvim-treeclimber.api").select_expand()
end, { desc = "select parent node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-forward-end)", function()
	require("nvim-treeclimber.api").select_forward_end()
end, { desc = "select and move to the end of the node, or the end of the next node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-backward)", function()
	require("nvim-treeclimber.api").select_backward()
end, { desc = "select and move to the begining of the node, or the beginning of the next node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-siblings-backward)", function()
	require("nvim-treeclimber.api").select_siblings_backward()
end, {})

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-siblings-forward)", function()
	require("nvim-treeclimber.api").select_siblings_forward()
end, {})

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-top-level)", function()
	require("nvim-treeclimber.api").select_top_level()
end, { desc = "select the top level node from the current position" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-previous)", function()
	require("nvim-treeclimber.api").select_backward()
end, { desc = "select previous node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-shrink)", function()
	require("nvim-treeclimber.api").select_shrink()
end, { desc = "select child node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-parent)", function()
	require("nvim-treeclimber.api").select_expand()
end, { desc = "select parent node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-next)", function()
	require("nvim-treeclimber.api").select_forward()
end, { desc = "select the next node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-grow-forward)", function()
	require("nvim-treeclimber.api").select_grow_forward()
end, { desc = "Add the next node to the selection" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-grow-backward)", function()
	require("nvim-treeclimber.api").select_grow_backward()
end, { desc = "Add the next node to the selection" })

-- User commands

vim.api.nvim_create_user_command("TCDiffThis", function()
	require("nvim-treeclimber.api").diff_this()
end, { force = true, range = true, desc = "" })

vim.api.nvim_create_user_command("TCHighlightExternalDefinitions", function()
	require("nvim-treeclimber.api").highlight_external_definitions()
end, { force = true, range = true, desc = "WIP" })

vim.api.nvim_create_user_command("TCShowControlFlow", function()
	require("nvim-treeclimber.api").show_control_flow()
end, {
	force = true,
	range = true,
	desc = "Populate the quick fix with all branches required to reach the current node",
})


local group = vim.api.nvim_create_augroup("nvim-treeclimber-colorscheme", { clear = true })

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	group = group,
	pattern = "*",
	callback = function()
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
	end,
})
