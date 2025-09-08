local loaded = false


local function api()
	if not loaded then
		loaded = true
		require("nvim-treeclimber").setup_highlights()
	end

	return require("nvim-treeclimber.api")
end

-- Keymaps
vim.keymap.set("n", "<Plug>(treeclimber-show-control-flow)", function()
	api().show_control_flow()
end, {})

vim.keymap.set({ "x", "o" }, "<Plug>(treeclimber-select-current-node)", function()
	api().select_current_node()
end, { desc = "select current node" })

vim.keymap.set({ "x", "o" }, "<Plug>(treeclimber-select-expand)", function()
	api().select_expand()
end, { desc = "select parent node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-forward-end)", function()
	api().select_forward_end()
end, { desc = "select and move to the end of the node, or the end of the next node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-backward)", function()
	api().select_backward()
end, { desc = "select and move to the begining of the node, or the beginning of the next node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-siblings-backward)", function()
	api().select_siblings_backward()
end, {})

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-siblings-forward)", function()
	api().select_siblings_forward()
end, {})

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-top-level)", function()
	api().select_top_level()
end, { desc = "select the top level node from the current position" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-previous)", function()
	api().select_backward()
end, { desc = "select previous node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-shrink)", function()
	api().select_shrink()
end, { desc = "select child node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-parent)", function()
	api().select_expand()
end, { desc = "select parent node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-next)", function()
	api().select_forward()
end, { desc = "select the next node" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-grow-forward)", function()
	api().select_grow_forward()
end, { desc = "Add the next node to the selection" })

vim.keymap.set({ "n", "x", "o" }, "<Plug>(treeclimber-select-grow-backward)", function()
	api().select_grow_backward()
end, { desc = "Add the next node to the selection" })

-- User commands

vim.api.nvim_create_user_command("TCDiffThis", function()
	api().diff_this()
end, { force = true, range = true, desc = "" })

vim.api.nvim_create_user_command("TCHighlightExternalDefinitions", function()
	api().highlight_external_definitions()
end, { force = true, range = true, desc = "WIP" })

vim.api.nvim_create_user_command("TCShowControlFlow", function()
	api().show_control_flow()
end, {
	force = true,
	range = true,
	desc = "Populate the quick fix with all branches required to reach the current node",
})

local group = vim.api.nvim_create_augroup("nvim-treeclimber-colorscheme", { clear = true })

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
	group = group,
	pattern = "*",
	callback = function()
		require("nvim-treeclimber").setup_highlights()
	end
})
