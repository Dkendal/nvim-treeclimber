local ts = vim.treesitter
local f = vim.fn
local a = vim.api
local uv = vim.loop
local logger = require("nvim-treeclimber.logger").new("Treeclimber log")
local pos = require("nvim-treeclimber.data.pos")
local pos_range = require("nvim-treeclimber.data.pos_range")
local RingBuffer = require("nvim-treeclimber.data.ring_buffer")

local M = {}

---@class tstree
---@field root fun(self: tstree):tsnode
---@field copy fun(self: tstree):tstree

---@class tsnode
---@field parent fun(self: tsnode): tsnode | nil
---@field next_sibling fun(self: tsnode): tsnode | nil
---@field prev_sibling fun(self: tsnode): tsnode | nil
---@field next_named_sibling fun(self: tsnode): tsnode | nil
---@field prev_named_sibling fun(self: tsnode): tsnode | nil
---@field iter_children fun(self: tsnode): fun(): tsnode, string
---@field field fun(self: tsnode, string): tsnode[]
---@field child_count fun(self: tsnode): tsnode | nil
---@field child fun(integer): tsnode | nil
---@field named_child_count fun(self: tsnode): tsnode | nil
---@field named_child fun(integer): tsnode | nil
---@field start fun(self: tsnode): integer, integer, integer
---@field end_ fun(self: tsnode): integer, integer, integer
---@field range fun(self: tsnode): number, number, number, number
---@field type fun(self: tsnode): string
---@field symbol fun(self: tsnode): integer
---@field named fun(self: tsnode): boolean
---@field missing fun(self: tsnode): boolean
---@field has_error fun(self: tsnode): boolean
---@field sexpr fun(self: tsnode): string
---@field id fun(self: tsnode): string
---@field descendant_for_range fun(self: tsnode, integer, integer, integer, integer): tsnode
---@field named_descendant_for_range fun(self: tsnode, integer, integer, integer, integer): tsnode

local ns = a.nvim_create_namespace("nvim-treeclimber")
local boundaries_ns = a.nvim_create_namespace("nvim-treeclimber-boundaries")

-- For reloading the file in dev
if vim.g.treeclimber_loaded then
	logger.clear()
	a.nvim_buf_clear_namespace(0, ns, 0, -1)
else
	vim.g.treeclimber_loaded = true
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

---@param bufnr number | nil
---@param lang string | nil
local function get_parser(bufnr, lang)
	return require("nvim-treesitter.parsers").get_parser(bufnr, lang)
end

---Returns the root node of the tree from the current parser
---@return tsnode
local function get_root()
	local parser = get_parser()
	---@type tstree
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
	local start = pos.to_vim({ node:start() })
	a.nvim_buf_set_mark(0, ">", start[1], start[2], {})
end

local function visual_select_end(node)
	local end_ = pos.to_vim({ node:end_() })

	local el = math.min(end_[1], f.line("$"))
	local ec = math.max(end_[2] - 1, 0)

	a.nvim_buf_set_mark(0, "<", el, ec, {})
end

local function visual_select_node(node)
	visual_select_start(node)
	visual_select_end(node)
end

local function visual_select_node_end(node)
	local start = pos.to_vim({ node:start() })
	local end_ = pos.to_vim({ node:end_() })

	local el = math.min(end_[1], f.line("$"))
	local ec = math.max(end_[2] - 1, 0)

	a.nvim_buf_set_mark(0, "<", start[1], start[2], {})
	a.nvim_buf_set_mark(0, ">", el, ec, {})
end

local function resume_visual_charwise()
	if f.visualmode() == "v" then
		vim.cmd.normal("gv")
	elseif f.visualmode() == "V" or f.visualmode() == "<CTRL-V>" then
		vim.cmd.normal("gvv")
	else
		vim.cmd.normal("gvgh")
	end
end

local function get_selection_range()
	local start = pos.to_ts(a.nvim_win_get_cursor(0))
	local end_ = pos.to_ts({ f.line("v"), f.col("v") })
	return start, end_
end

---Get the node that spans the range
---@param start pos
---@param end_ pos
---@return tsnode
local function get_covering_node(start, end_)
	local root = get_root()
	local list = { start, end_ }
	table.sort(list, pos.lt)
	e, s = list[1], list[2]

	-- Smallest node that covers the selection end to end
	local covering_node = root:named_descendant_for_range(s[1], s[2], e[1], e[2])

	return covering_node
end

-- Get a node above this one that would grow the selection
local function get_larger_ancestor(node, start, end_)
	while node and pos_range.eq({ { node:start() }, { node:end_() } }, { start, end_ }) do
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

---Apply highlights
---@param node tsnode
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

		a.nvim_buf_set_extmark(0, ns, sl, sc, {
			hl_group = "TreeClimberParentStart",
			strict = false,
		})

		for child in parent:iter_children() do
			if child:id() ~= node:id() and child:named() then
				local sl, sc = unpack({ child:start() })
				local el, ec = unpack({ child:end_() })

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

	if is_selected_cursor_start(node, start, end_) and node:prev_named_sibling() then
		node = node:prev_named_sibling()
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function M.select_siblings_backward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node:prev_named_sibling() do
		node = node:prev_named_sibling()
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

	if node:prev_named_sibling() then
		node = node:prev_named_sibling()
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

	if pos.eq({ parent:end_() }, end_) and pos.eq({ parent:start() }, start) then
		return { parent }
	end

	local nodes = {}

	for child in parent:iter_children() do
		if child:named() and pos.gte({ child:start() }, start) and pos.lte({ child:end_() }, end_) then
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
		snode = snode:prev_named_sibling() or snode
		visual_select_start(snode)
		visual_select_end(enode)
		resume_visual_charwise()
	end
end

function M.draw_boundary()
	a.nvim_buf_clear_namespace(0, boundaries_ns, 0, -1)

	local pos_ = pos.to_ts(a.nvim_win_get_cursor(0))
	local node = ts.get_node({ pos = pos_ })
	-- grow selection until it matches one of the types

	local i = 0
	while true do
		local row, col = node:start()
		local end_row, end_col = node:end_()

		a.nvim_buf_set_extmark(0, boundaries_ns, row, col, {
			hl_group = "StatusLine" .. i,
			end_col = end_col,
			end_row = end_row,
			strict = false,
		})
		i = i + 1

		-- row, col = node:end_()
		--
		-- a.nvim_buf_set_extmark(0, boundaries_ns, row, col - 1, {
		-- 	hl_group = "SignColumn",
		-- 	end_col = col + 1,
		-- 	strict = false,
		-- })

		node = node:parent()

		if node == nil then
			return
		end
	end

	return node:sexpr()
end

local function set_normal_mode()
	a.nvim_feedkeys(a.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
end

local diff_ring = RingBuffer.new(2)

--- Diff two selections using difft in a new window.
function M.diff_this(opts)
	local text = a.nvim_buf_get_text(0, opts.line1 - 1, 0, opts.line2 - 1, -1, {})
	diff_ring:put(text)
	if diff_ring.index == 1 then
		local file_a = f.tempname()
		local file_b = f.tempname()
		local contents_a = diff_ring:get()
		local contents_b = diff_ring:get()
		f.writefile(contents_a, file_a)
		f.writefile(contents_b, file_b)
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

return M
