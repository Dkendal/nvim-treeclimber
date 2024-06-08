vim.o.swapfile = false
vim.bo.swapfile = false

vim.o.runtimepath = vim.o.runtimepath .. ",."

require("nvim-treesitter.configs").setup({
	ensure_installed = { "lua" },
	sync_install = true
})
