local ts = vim.treesitter
local f = vim.fn
local a = vim.api
local logger = require("nvim-treeclimber.logger").new("Treeclimber log")
local Pos = require("nvim-treeclimber.pos")
local Range = require("nvim-treeclimber.range")
local Stack = require("nvim-treeclimber.stack")
local RingBuffer = require("nvim-treeclimber.ring_buffer")
local argcheck = require("nvim-treeclimber.typecheck").argcheck

local api = {}
api.node = {}
api.buf = {}

local ns = a.nvim_create_namespace("nvim-treeclimber")
local boundaries_ns = a.nvim_create_namespace("nvim-treeclimber-boundaries")

-- For reloading the file in dev
if vim.g.treeclimber_loaded then
	logger.clear()
	a.nvim_buf_clear_namespace(0, ns, 0, -1)
else
	vim.g.treeclimber_loaded = true
end

--- @alias treeclimber.History Range4[]
--- @type treeclimber.History
local plug_history = {}

--- @param t table
local function tbl_clear(t)
	local count = #t
	for i = 0, count do
		t[i] = nil
	end
end

--- @param node TSNode
local function push_history(node)
	local top = Stack.peek(plug_history)
	local new_value = { node:range() }

	if vim.deep_equal(top, new_value) then
		return
	end

	table.insert(plug_history, new_value)
end

local top_level_types = {
	["function_declaration"] = true,
}

---@param bufnr integer?
---@param lang string?
---@return vim.treesitter.LanguageTree
local function get_parser(bufnr, lang)
	return vim.treesitter.get_parser(bufnr, lang)
end

---Returns the root node of the tree from the current parser
---@return TSNode
function api.buf.get_root()
	local parser = get_parser()
	local tree = parser:parse()[1]
	return tree:root()
end

---@return number, number
function api.buf.get_cursor()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	return row, col
end

---@return TSNode?
function api.buf.get_node_under_cursor()
	local root = api.buf.get_root()
	local row, col = api.buf.get_cursor()
	return root:descendant_for_range(row, col, row, col)
end

---@param node TSNode
---@return string
function api.node.get_text(node)
	return vim.treesitter.query.get_node_text(node, 0)
end

function api.show_control_flow()
	local node = api.buf.get_node_under_cursor()
	local prev = node
	local p = {}

	local function push(v)
		table.insert(p, v)
	end

	push({ start = f.line(".") - 1, msg = "[current-line]" })

	while node do
		if prev and prev ~= node then
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
				push({ start = node:start(), msg = string.format("if %s", api.node.get_text(n)) })
			end
		elseif type == "function_declaration" then
			push({
				start = node:start(),
				msg = string.format("function %s(...)", api.node.get_text(node:field("name")[1])),
			})
		elseif type == "variable_declarator" and node:field("value")[1]:type() == "arrow_function" then
			push({
				start = node:start(),
				msg = string.format("%s = (...) =>", api.node.get_text(node:field("name")[1])),
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
function api.in_temp_win(name, lines)
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
	local start = Pos.to_vim({ node:start() })
	a.nvim_buf_set_mark(0, ">", start[1], start[2], {})
end

local function visual_select_end(node)
	local end_ = Pos.to_vim({ node:end_() })

	local el = math.min(end_[1], f.line("$"))
	local ec = math.max(end_[2] - 1, 0)

	a.nvim_buf_set_mark(0, "<", el, ec, {})
end

local function visual_select_node(node)
	visual_select_start(node)
	visual_select_end(node)
end

local function visual_select_node_end(node)
	local start = Pos.to_vim({ node:start() })
	local end_ = Pos.to_vim({ node:end_() })

	local el = math.min(end_[1], f.line("$"))
	local ec = math.max(end_[2] - 1, 0)

	a.nvim_buf_set_mark(0, "<", start[1], start[2], {})
	a.nvim_buf_set_mark(0, ">", el, ec, {})
end

local function resume_visual_charwise()
	if f.visualmode() == "v" then
		vim.cmd.normal("gv")
	elseif
	-- 22 is the unicode decimal representation of <C-V>
			f.visualmode() == "V" or f.visualmode() == "\22"
	then
		vim.cmd.normal("gvv")
	else
		vim.cmd.normal("gvgh")
	end
end

---@deprecated use `api.doc.get_selection_range`
local function get_selection_range()
	local start = Pos.to_ts(a.nvim_win_get_cursor(0))
	local end_ = Pos.to_ts({ f.line("v"), f.col("v") })
	return start, end_
end

---@return treeclimber.Range
function api.buf.get_selection_range()
	local from = Pos.to_ts(a.nvim_win_get_cursor(0))
	local to = Pos.to_ts({ f.line("v"), f.col("v") })
	return Range.new(from, to)
end

---Get the node that spans the range
---@param range treeclimber.Range
---@return TSNode?
function api.buf.get_covering_node(range)
	local root = api.buf.get_root()
	return api.node.largest_named_descendant_for_range(root, range:to_list())
end

---Get the node that is currently selected, either in visual or normal mode
---@return TSNode?
function api.buf.get_selected_node()
	local range = api.buf.get_selection_range()
	return api.buf.get_covering_node(range)
end

---Get the node that spans the range
---@param start treeclimber.Pos
---@param end_ treeclimber.Pos
---@return TSNode?
local function get_covering_node(start, end_)
	local root = api.buf.get_root()
	local range = Range.new(Pos.from_list(start), Pos.from_list(end_))
	return api.node.largest_named_descendant_for_range(root, range:to_list())
end

---Get the node that spans the range
---@param node TSNode
---@param range treeclimber.Range
---@return TSNode?
function api.node.named_descendant_for_range(node, range)
	return node:named_descendant_for_range(range:values())
end

---Get the largest node that spans the range
---@param node TSNode
---@param range Range4
---@return TSNode?
function api.node.largest_named_descendant_for_range(node, range)
	local prev = node:named_descendant_for_range(unpack(range))

	if prev == nil then
		return
	end

	---@type TSNode?
	local next = prev

	repeat
		assert(next, "Expected TSNode")
		prev = next
		next = prev:parent()
	until not next or not vim.deep_equal({ next:range() }, { prev:range() })

	return prev
end

-- Get a node above this one that would grow the selection
---@param node TSNode
---@param range treeclimber.Range
---@return TSNode
function api.get_larger_ancestor(node, range)
	---@type TSNode?
	local acc = node
	local prev = node

	while acc and api.node.has_range(acc, range) do
		prev = acc
		acc = acc:parent()
	end

	return acc or prev
end

-- Check if visual selection is covering the node, with the cursor at the end
local function is_selected_cursor_end(node, start, end_)
	local sr, sc, er, ec = node:range()
	return er == start[1] and ec == (start[2] + 1) and sr == end_[1] and sc == (end_[2] - 1)
end

---@deprecated use `is_selected_cursor_start_v2`
---@param node TSNode
---@param start treeclimber.Pos
---@param end_ treeclimber.Pos
local function is_selected_cursor_start(node, start, end_)
	local sr, sc, er, ec = node:range()
	return sr == start[1] and sc == start[2] and er == end_[1] and ec == end_[2]
end

---Apply highlights
---@param node TSNode
local function apply_decoration(node)
	argcheck("treeclimber.api.apply_decoration", 1, "userdata", node)

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

		a.nvim_buf_set_extmark(0, ns, sl, sc, {
			hl_group = "TreeClimberParentStart",
			strict = false,
		})

		for child in parent:iter_children() do
			if child:id() ~= node:id() and child:named() then
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

function api.select_current_node()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_expand()
	local node = api.buf.get_selected_node()

	if not node then
		return
	end

	node = api.node.grow(node)

	if not node then
		return
	end

	push_history(node)

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_shrink()
	local range = api.buf.get_selection_range()
	local root = api.buf.get_root()
	local node = api.node.largest_named_descendant_for_range(root, range:to_list())
	--- @type TSNode?
	local next_node

	if not node then
		return
	end

	next_node = api.node.shrink(node, plug_history)

	apply_decoration(next_node)
	visual_select_node(next_node)
	resume_visual_charwise()
end

function api.select_top_level()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node and node:parent() do
		if top_level_types[node:parent():type()] then
			push_history(node)
			node = node:parent()
			break
		else
			node = node:parent()
		end
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_forward_end()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	if is_selected_cursor_end(node, start, end_) and node:next_sibling() then
		node = node:next_sibling()
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node_end(node)
	resume_visual_charwise()
end

function api.select_backward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	if is_selected_cursor_start(node, start, end_) and node:prev_named_sibling() then
		node = node:prev_named_sibling()
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_siblings_backward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node and node:prev_named_sibling() do
		node = node:prev_named_sibling()
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_siblings_forward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	while node and node:next_sibling() do
		node = node:next_sibling()
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_prev_node()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	if node:prev_named_sibling() then
		node = node:prev_named_sibling()
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visual_select_node(node)
	resume_visual_charwise()
end

function api.select_forward()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	if node:next_sibling() then
		node = node:next_sibling()
	end

	if node == nil then
		return
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

	if Pos.eq({ parent:end_() }, end_) and Pos.eq({ parent:start() }, start) then
		return { parent }
	end

	local nodes = {}

	for child in parent:iter_children() do
		if child:named() and Pos.gte({ child:start() }, start) and Pos.lte({ child:end_() }, end_) then
			table.insert(nodes, child)
		end
	end

	return nodes
end

function api.select_grow_forward()
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

function api.select_grow_backward()
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

---@param node TSNode
---@param range treeclimber.Range
function api.node.has_range(node, range)
	return Range.new4(node:range()) == range
end

---@param node TSNode
---@return TSNode?
function api.node.grow(node)
	local next = node
	local range = Range.from_node(node)

	if not next then
		return
	end

	if not api.node.has_range(next, range) then
		return next
	end

	local ancestor = api.get_larger_ancestor(next, range)

	return ancestor or next
end

---@param node TSNode
---@param history treeclimber.History
---@return TSNode
function api.node.shrink(node, history)
	argcheck("treeclimber.api.node.shrink", 1, "userdata", node)
	argcheck("treeclimber.api.node.shrink", 2, "table", history)

	---@type TSNode
	local prev = node
	---@type TSNode?
	local next = node

	if #history > 0 then
		--- @type Range4
		local descendant_range

		repeat
			descendant_range = Stack.pop(history)
		until #history == 0 or not vim.deep_equal(descendant_range, { node:range() })
		-- Ignore the current node

		-- Only return a previously visited node if it's a descendant of the current node
		if descendant_range and vim.treesitter.node_contains(node, descendant_range) then
			next = api.node.largest_named_descendant_for_range(node, descendant_range)
			-- This should always be true
			assert(next, "Expected a node")
			-- Make sure to push this node back onto the stack
			push_history(next)
			return next
		end
	end

	-- Clear history, as the node is not a descendant of the current node
	tbl_clear(history)

	local range = Range.from_node(node)

	while next and api.node.has_range(next, range) and next:named_child_count() > 0 do
		prev = next
		next = next:named_child(0)
		if not next then
			break
		end
	end

	return next or prev
end

function api.draw_boundary()
	a.nvim_buf_clear_namespace(0, boundaries_ns, 0, -1)

	local pos_ = Pos.to_ts(a.nvim_win_get_cursor(0))
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

		node = node:parent()

		if node == nil then
			return
		end
	end
end

local function set_normal_mode()
	a.nvim_feedkeys(a.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
end

local diff_ring = RingBuffer.new(2)

--- Diff two selections using difft in a new window.
function api.diff_this(opts)
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
function api.highlight_external_definitions()
	set_normal_mode()
	resume_visual_charwise()
	local start, end_ = get_selection_range()
	local node = get_covering_node(start, end_)

	local query = ts.query.parse(
		vim.o.filetype,
		[[
		(lexical_declaration (variable_declarator name: ((identifier) @def)))
		(function_declaration name: ((identifier) @def))
		((member_expression) @member)
		((identifier) @id)
	]]
	)

	local definitions = {}

	assert(node, "No node found")

	for id, child in query:iter_captures(node, 0, 0, -1) do
		local name = query.captures[id] -- name of the capture in the query
		-- typically useful info about the node:
		-- local type = node:type() -- type of the captured node
		-- local row1, col1, row2, col2 = node:range() -- range of the capture
		-- vim.pretty_print(tsnode_get_text(node))
		local text = api.node.get_text(child)
		if name == "def" then
			table.insert(definitions, text)
		elseif not definitions[text] then
			-- TODO: drill into a member expression to get the identifier
			vim.pretty_print("WARN " .. text)
		end
	end
end

return api
