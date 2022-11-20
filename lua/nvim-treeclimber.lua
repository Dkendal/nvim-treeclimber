---@alias tsnode {}
---@alias v2 {integer, integer}
---@alias range {v2, v2}

local ts = vim.treesitter
local f = vim.fn
local a = vim.api
local uv = vim.loop
local logger = require("nvim-treeclimber.logger").new("Treeclimber log")

-- Clear logger for development
logger.clear()

local M = {}

local ns = a.nvim_create_namespace("nvim-treeclimber")
-- For resourcing the file
a.nvim_buf_clear_namespace(0, ns, 0, -1)

-- Convert 1 indexed row to 0 indexed
-- Vim pos -> Tree-sitter pos
---@param v v2
---@return v2
local function v2_to_ts(v)
	return { v[1] - 1, v[2] }
end

-- Convert 0 indexed row to 1 indexed
-- Tree-sitter pos -> Vim pos
---@param v v2
---@return v2
local function v2_to_vim(v)
	return { v[1] + 1, v[2] }
end

---@param a v2
---@param b v2
---@return boolean
local function v2_gt(a, b)
	if a[1] == b[1] then
		return a[2] > b[2]
	end
	return a[1] > b[1]
end

---@param a v2
---@param b v2
---@return boolean
local function v2_eq(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

---@param a v2
---@param b v2
---@return boolean
local function v2_gte(a, b)
	return v2_gt(a, b) or v2_eq(a, b)
end

---@param a v2
---@param b v2
---@return boolean
local function v2_lt(a, b)
	return not v2_gt(b, a) and not v2_eq(b, a)
end

---@param a v2
---@param b v2
---@return boolean
local function v2_lte(a, b)
	return not v2_gt(a, b)
end

---@param a range
---@param b range
---@return boolean
local function range_eq(a, b)
	return v2_eq(a[1], b[1]) and v2_eq(a[2], b[2])
end

-- A covers B
---@param a range
---@param b range
---@return boolean
local function range_covers(a, b)
	return v2_lte(a[1], b[1]) and v2_gte(a[2], b[2])
end

local visit_list = {}

function visit_list:push(node)
	table.insert(visit_list, { { node:start() }, { node:end_() } })
end

function visit_list:pop()
	return table.remove(visit_list)
end

local stack = {}

function stack.push(item)
	table.insert(stack, item)
end

function stack.pop()
	return table.remove(stack)
end

local top_level_types = {
	["function_declaration"] = true,
}

local function get_root()
	local parser = vim.treesitter.get_parser(0, vim.o.filetype, {})
	local tree = parser:parse()[1]
	return tree:root()
end

---@param a table
---@param b table
---@return boolean
--- Check if b is a subset of a
local function array_subset(a, b)
	for k, v in pairs(a) do
		if type(k) == "number" then
			if v ~= b[k] then
				return false
			end
		end
	end
	return true
end

---@param a table
---@param b table
---@return boolean
--- Check if two tables are equal by value
local function tbl_eq(a, b)
	if #a ~= #b then
		return false
	end
	for k, v in pairs(a) do
		if v ~= b[k] then
			return false
		end
	end
end

---@return number, number
local function get_cursor()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	return row, col
end

---@return tsnode
local function get_node_under_cursor()
	local root = get_root()
	local row, col = get_cursor()
	return root:descendant_for_range(row, col, row, col)
end

local function pos_move_cursor(r, c)
	a.nvim_win_set_cursor(0, { r + 1, c })
end

---@param node tsnode
local function tsnode_get_text(node)
	return vim.treesitter.query.get_node_text(node, 0)
end

function M.show_control_flow()
	local node = get_node_under_cursor()
	local prev = node
	local p = {}

	local function push(v)
		table.insert(p, v)
	end

	push({ start = f.line(".") - 1, msg = "[current-line]" })

	while node do
		if prev ~= node then
			local type = node:type()
			if type == "if_statement" or type == "ternary_expression" then
				for _, n in ipairs(node:field("consequence")) do
					-- check to see if prev is contained within n
					local sr1, sc1, er1, ec1 = n:range()
					local sr2, sc2, er2, ec2 = prev:range()
					if sr1 <= sr2 and (sr1 ~= sr2 or sc1 <= sc2) and er1 >= er2 and (er1 ~= er2 or ec1 >= ec2) then
						-- push({ start = node:start(), msg = "then" })
						break
					end
				end

				for _, n in ipairs(node:field("alternative")) do
					-- check to see if prev is contained within n
					local sr1, sc1, er1, ec1 = n:range()
					local sr2, sc2, er2, ec2 = prev:range()
					if sr1 <= sr2 and (sr1 ~= sr2 or sc1 <= sc2) and er1 >= er2 and (er1 ~= er2 or ec1 >= ec2) then
						push({ start = node:start(), msg = "else" })
						break
					end
				end
			end
		end

		local type = node:type()

		if type == "ternary_expression" or type == "if_statement" then
			for _, n in ipairs(node:field("condition")) do
				push({ start = node:start(), msg = string.format("if %s", tsnode_get_text(n)) })
			end
		elseif type == "function_declaration" then
			push({
				start = node:start(),
				msg = string.format("function %s(...)", tsnode_get_text(node:field("name")[1])),
			})
		elseif type == "variable_declarator" and node:field("value")[1]:type() == "arrow_function" then
			push({
				start = node:start(),
				msg = string.format("%s = (...) =>", tsnode_get_text(node:field("name")[1])),
			})
		end
		node = node:parent()
	end

	local list = {}

	local bufnr = f.bufnr()
	for i = #p, 1, -1 do
		local item = p[i]
		table.insert(list, {
			lnum = item.start + 1,
			bufnr = bufnr,
			text = item.msg,
		})
	end

	f.setqflist(list, "r")
	vim.cmd([[bel copen ]] .. #list)
end

---@param name string
---@param lines table
-- write lines to a temporary buffer with `name`, and open the buffer as a floating window
function M.in_temp_win(name, lines)
	local bufnr = f.bufnr(name, true)

	f.bufload(name)

	local is_visible = not f.win_findbuf(bufnr)[1]

	-- check if window is visible
	if is_visible then
		vim.cmd(string.format("bel 0sp %s", name))
	end

	a.nvim_buf_call(bufnr, function()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		a.nvim_win_set_height(0, #lines)
	end)
end

local function visual_select_start(node)
	local start = v2_to_vim({ node:start() })
	a.nvim_buf_set_mark(0, ">", start[1], start[2], {})
end

local function visual_select_end(node)
	local end_ = v2_to_vim({ node:end_() })

	local el = math.min(end_[1], f.line("$"))
	local ec = math.max(end_[2] - 1, 0)

	a.nvim_buf_set_mark(0, "<", el, ec, {})
end

local function visual_select_node(node)
	visual_select_start(node)
	visual_select_end(node)
end

local function visual_select_node_end(node)
	local start = v2_to_vim({ node:start() })
	local end_ = v2_to_vim({ node:end_() })

	local el = math.min(end_[1], f.line("$"))
	local ec = math.max(end_[2] - 1, 0)

	a.nvim_buf_set_mark(0, "<", start[1], start[2], {})
	a.nvim_buf_set_mark(0, ">", el, ec, {})
end

local function resume_visual_charwise()
	if f.visualmode() == "v" then
		vim.cmd.normal("gv")
	else
		vim.cmd.normal("gvgh")
	end
end

local function get_selection_range()
	local start = v2_to_ts(a.nvim_win_get_cursor(0))
	local end_ = v2_to_ts({ f.line("v"), f.col("v") })
	return start, end_
end

local function get_covering_node(start, end_)
	local parser = ts.get_parser(0, vim.o.filetype, {})
	local tree = parser:parse()[1]
	local root = tree:root()
	local list = { start, end_ }
	table.sort(list, v2_lt)
	e, s = list[1], list[2]

	-- Smallest node that covers the selection end to end
	local covering_node = root:named_descendant_for_range(s[1], s[2], e[1], e[2])

	return covering_node
end

-- Get a node above this one that would grow the selection
local function get_larger_ancestor(node, start, end_)
	while node and range_eq({ { node:start() }, { node:end_() } }, { start, end_ }) do
		node = node:parent()
	end

	return node
end

-- Check if visual selection is covering the node, with the cursor at the end
function is_selected_cursor_end(node, start, end_)
	local sr, sc, er, ec = node:range()
	return er == start[1] and ec == (start[2] + 1) and sr == end_[1] and sc == (end_[2] - 1)
end

local function is_selected_cursor_start(node, start, end_)
	local sr, sc, er, ec = node:range()
	return sr == start[1] and sc == start[2] and er == end_[1] and ec == end_[2]
end

local function apply_decoration(node)
	a.nvim_buf_clear_namespace(0, ns, 0, -1)

	local function cb()
		vim.defer_fn(function()
			local mode = a.nvim_get_mode()
			if mode.blocking == false and mode.mode ~= "v" then
				a.nvim_buf_clear_namespace(0, ns, 0, -1)
			else
				cb()
			end
		end, 500)
	end

	cb()

	local parent = node:parent()

	if parent then
		local sl, sc = unpack({ parent:start() })
		local el, ec = unpack({ parent:end_() })

		-- a.nvim_buf_set_extmark(0, ns, sl, sc + 1, {
		-- 	hl_group = "TreeClimberParent",
		-- 	strict = false,
		-- 	end_line = el,
		-- 	end_col = ec,
		-- })

		a.nvim_buf_set_extmark(0, ns, sl, sc, {
			hl_group = "TreeClimberParentStart",
			strict = false,
			-- end_line = sl,
			-- end_col = sc + 1,
		})

		for child in parent:iter_children() do
			if child:id() ~= node:id() and child:named() then
				local sl, sc = unpack({ child:start() })
				local el, ec = unpack({ child:end_() })

				-- 				a.nvim_buf_set_extmark(0, ns, sl, sc + 1, {
				-- 					hl_group = "TreeClimberSibling",
				-- 					strict = false,
				-- 					end_line = el,
				-- 					end_col = ec - 1,
				-- 				})

				a.nvim_buf_set_extmark(0, ns, sl, sc, {
					hl_group = "TreeClimberSiblingBoundary",
					strict = false,
					-- end_line = sl,
					end_col = sc + 1,
				})

				a.nvim_buf_set_extmark(0, ns, sl, sc + 1, {
					hl_group = "TreeClimberSibling",
					strict = false,
					end_line = el,
					end_col = ec,
				})
			end
		end
	end
end

function M.select_current_node()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)
	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_expand()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if is_selected_cursor_start(node, start, end_) then
		local ancestor = get_larger_ancestor(node:parent(), start, end_)

		if ancestor then
			visit_list:push(node)
			node = ancestor
		end
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_top_level()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node:parent() do
		if top_level_types[node:parent():type()] then
			vim.pretty_print(node:type())
			visit_list:push(node)
			node = node:parent()
			break
		else
			node = node:parent()
		end
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_shrink()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)
	local next_node = nil

	if #visit_list > 0 then
		local last = visit_list:pop()
		local last_node = get_covering_node(last[1], last[2])
		if ts.is_ancestor(node, last_node) then
			next_node = last_node
		end
	end

	if not next_node then
		if node:named_child_count() > 0 then
			next_node = node:named_child(0)
		else
			next_node = node
		end
	end

	apply_decoration(next_node)
	visual_select_node(next_node)
	resume_visual_charwise()
end

function M.select_forward_end()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if is_selected_cursor_end(node, start, end_) and node:next_sibling() then
		node = node:next_sibling()
	end

	apply_decoration(node)
	visual_select_node_end(node)
	resume_visual_charwise()
end

function M.select_backward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if is_selected_cursor_start(node, start, end_) and node:prev_sibling() then
		node = node:prev_sibling()
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_siblings_backward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node:prev_sibling() do
		node = node:prev_sibling()
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_siblings_forward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node:next_sibling() do
		node = node:next_sibling()
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_prev_node()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node:prev_sibling() then
		node = node:prev_sibling()
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_forward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node:next_sibling() then
		node = node:next_sibling()
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

-- Start with the covering node, if the start and end match it's exactly
-- then return it, otherwise find the slice of the node that most closesly
-- matches the selection
local function get_covering_nodes(start, end_)
	local parent = get_covering_node(start, end_)

	if parent == nil then
		return nil
	end

	if v2_eq({ parent:end_() }, end_) and v2_eq({ parent:start() }, start) then
		return { parent }
	end

	local nodes = {}

	for child in parent:iter_children() do
		if v2_gte({ child:start() }, start) and v2_lte({ child:end_() }, end_) then
			table.insert(nodes, child)
		end
	end

	return nodes
end

function M.select_grow_forward()
	local start, end_ = get_selection_range()
	local nodes = get_covering_nodes(start, end_)

	if nodes and #nodes > 0 then
		local snode = nodes[1]
		local enode = nodes[#nodes]
		enode = enode:next_sibling() or enode
		visual_select_start(snode)
		visual_select_end(enode)
		resume_visual_charwise()
	end
end

function M.select_grow_backward()
	local start, end_ = get_selection_range()
	local nodes = get_covering_nodes(start, end_)

	if nodes and #nodes > 0 then
		local snode = nodes[1]
		local enode = nodes[#nodes]
		snode = snode:prev_sibling() or snode
		visual_select_start(snode)
		visual_select_end(enode)
		resume_visual_charwise()
	end
end

local function set_normal_mode()
	a.nvim_feedkeys(a.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
end

local diff_ring = { index = 0, size = 2 }

function diff_ring:push(value)
	local i = self.index % self.size + 1
	self.index = i
	self[i] = value
end

--- Diff two selections using difft in a new window.
function M.diff_this(opts)
	local text = a.nvim_buf_get_text(0, opts.line1 - 1, 0, opts.line2 - 1, -1, {})
	diff_ring:push(text)
	if diff_ring.index == 2 then
		local file_a = f.tempname()
		local file_b = f.tempname()
		f.writefile(diff_ring[1], file_a)
		f.writefile(diff_ring[2], file_b)
		vim.cmd("botright sp")
		vim.cmd(table.concat({
			"terminal",
			"difft",
			"--color",
			"always",
			"--language",
			f.expand("%:e"),
			file_a,
			file_b,
			"|",
			"less",
			"-R",
		}, " "))
	end
end

-- Get the node that is currently selected, then highlight all identifiers that
-- are not defined within the current scope.
function M.highlight_external_definitions(opts)
	set_normal_mode()
	resume_visual_charwise()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	local query = ts.parse_query(
		vim.o.filetype,
		[[
		(lexical_declaration (variable_declarator name: ((identifier) @def)))
		(function_declaration name: ((identifier) @def))
		((member_expression) @member)
		((identifier) @id)
	]]
	)

	local definitions = {}

	for id, node, metadata in query:iter_captures(node, 0, 0, -1) do
		local name = query.captures[id] -- name of the capture in the query
		-- typically useful info about the node:
		-- local type = node:type() -- type of the captured node
		-- local row1, col1, row2, col2 = node:range() -- range of the capture
		-- vim.pretty_print(tsnode_get_text(node))
		local text = tsnode_get_text(node)
		if name == "def" then
			table.insert(definitions, text)
		elseif not definitions[text] then
			-- TODO: drill into a member expression to get the identifier
			vim.pretty_print(text)
		end
	end
end

function M.setup()
	local color = require("nvim-treeclimber.hi")
	local bg = color.bg_hsluv("Normal")
	local fg = color.fg_hsluv("Normal")
	local dim = bg.mix(fg, 20)

	a.nvim_set_hl(0, "TreeClimberHighlight", { background = dim.hex })

	a.nvim_set_hl(0, "TreeClimberSiblingBoundary", { background = color.terminal_color_5.hex })

	a.nvim_set_hl(0, "TreeClimberSibling", { background = color.terminal_color_5.mix(bg, 40).hex, bold = true })

	a.nvim_set_hl(0, "TreeClimberParent", { background = bg.mix(fg, 2).hex })

	a.nvim_set_hl(0, "TreeClimberParentStart", { background = color.terminal_color_4.mix(bg, 10).hex, bold = true })

	local map = vim.keymap.set

	map("n", "<leader>k", M.show_control_flow, {})

	map({ "x", "o" }, "i.", M.select_current_node, { desc = "select current node" })

	map({ "x", "o" }, "a.", M.select_expand, { desc = "select parent node" })

	map(
		{ "n", "x", "o" },
		"<M-e>",
		M.select_forward_end,
		{ desc = "select and move to the end of the node, or the end of the next node" }
	)

	map(
		{ "n", "x", "o" },
		"<M-b>",
		M.select_backward,
		{ desc = "select and move to the begining of the node, or the beginning of the next node" }
	)

	map({ "n", "x", "o" }, "<M-[>", M.select_siblings_backward, {})

	map({ "n", "x", "o" }, "<M-]>", M.select_siblings_forward, {})

	map(
		{ "n", "x", "o" },
		"<M-g>",
		M.select_top_level,
		{ desc = "select the top level node from the current position" }
	)

	map({ "n", "x", "o" }, "<M-h>", M.select_backward, { desc = "select previous node" })

	map({ "n", "x", "o" }, "<M-j>", M.select_shrink, { desc = "select child node" })

	map({ "n", "x", "o" }, "<M-k>", M.select_expand, { desc = "select parent node" })

	map({ "n", "x", "o" }, "<M-l>", M.select_forward, { desc = "select the next node" })

	map({ "n", "x", "o" }, "<M-L>", M.select_grow_forward, { desc = "Add the next node to the selection" })

	map({ "n", "x", "o" }, "<M-H>", M.select_grow_backward, { desc = "Add the next node to the selection" })
end

a.nvim_create_user_command("TCDiffThis", M.diff_this, { force = true, range = true, desc = "" })

a.nvim_create_user_command(
	"TCHighlightExternalDefinitions",
	M.highlight_external_definitions,
	{ force = true, range = true, desc = "WIP" }
)

return M
