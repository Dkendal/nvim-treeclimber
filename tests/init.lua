local M = {}

function M.root(root)
	local f = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

---@param plugin string
function M.load(plugin)
	local name = plugin:match(".*/(.*)")

	local package_root = M.root(".tests/site/pack/deps/start/")

	if not vim.uv.fs_stat(package_root .. name) then
		print("Installing " .. plugin)
		vim.fn.mkdir(package_root, "p")
		vim.fn.system({
			"git",
			"clone",
			"--depth=1",
			"https://github.com/" .. plugin .. ".git",
			package_root .. "/" .. name,
		})
	end
end

function M.setup()
	vim.opt.runtimepath:append(".")
	vim.opt.packpath = { ".tests/site" }

	M.load("nvim-lua/plenary.nvim")
	M.load("nvim-treesitter/nvim-treesitter")

	vim.o.swapfile = false
	vim.bo.swapfile = false
	vim.env.XDG_CONFIG_HOME = M.root(".tests/config")
	vim.env.XDG_DATA_HOME = M.root(".tests/data")
	vim.env.XDG_STATE_HOME = M.root(".tests/state")
	vim.env.XDG_CACHE_HOME = M.root(".tests/cache")

	-- TODO: figure out how to include parsers
	require("nvim-treesitter.configs").setup({
		indent = { enable = false },
		highlight = { enable = false },
	})
end

M.setup()
