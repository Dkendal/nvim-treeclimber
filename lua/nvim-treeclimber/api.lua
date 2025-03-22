local ts = vim.treesitter
local f = vim.fn
local a = vim.api
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
	a.nvim_buf_clear_namespace(0, ns, 0, -1)
else
	vim.g.treeclimber_loaded = true
end

-- FIXME: If there's going to be a Stack class, it should probably subsume the logic
-- below; currently, plug_history is just a table.
--- @alias treeclimber.History Range4[]
--- @type treeclimber.History
local plug_history = {}

-- Node Stack Logic: Push range (possibly corresponding to multiple nodes) on ascent; clear *entire*
-- stack on any lateral movement that changes selection. Also, clear history on attempt to descend
-- when the range at the top of the stack is *outside* the descended-from node.
-- TODO: Consider advantages of associating a parent id with ranges pushed to the stack. This would
-- allow us to be certain that a range had been pushed for a node or nodes at the target level (and
-- not for a child or range of children from an even lower level). However, the extra complexity may
-- not be worth it. Logic in api.node.shrink prevents descending more than one node at a time, and
-- it currently ignores a pushed range that doesn't correspond exactly to a node or range of nodes
-- at the target level.

-- Push range onto the history stack (or overwrite top entry if overwrite == true).
--- @param range Range4
--- @param overwrite boolean?
local function push_history(range, overwrite)
	if overwrite then
		-- TODO: Can we assume overwritten element is sibling? Currently, we rely
		-- on external plugin logic to guarantee this.
		plug_history[#plug_history > 0 and #plug_history or 1] = range
	else
		-- Don't add redundant element.
		local top = Stack.peek(plug_history)
		if vim.deep_equal(top, range) then
			return
		end
		Stack.push(plug_history, range)
	end
end

-- Pop top element from the history stack and return it.
---@return Range4
local function pop_history()
	return Stack.pop(plug_history)
end

-- Clear all elements from the history stack.
local function clear_history()
	plug_history = {}
end

-- Return number of elements in history stack.
---@return integer
local function history_size()
	return #plug_history
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

---@return integer, integer
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

--- Changes the > mark to the start of the node
--- @param node TSNode
local function set_visual_start(node)
	local start = Pos:new(node:start()):to_vim()
	a.nvim_buf_set_mark(0, ">", start.row, start.col, {})
end

--- Changes the < mark to the start of the node
--- @param node TSNode
local function set_visual_end(node)
	local end_ = Pos:new(node:end_()):to_vim()

	local el = math.min(end_.row, f.line("$"))
	local ec = math.max(end_.col - 1, 0)

	a.nvim_buf_set_mark(0, "<", el, ec, {})
end

--- Changes the > and < mark to match the node's text region
--- @param node TSNode
local function visually_select_node(node)
	set_visual_start(node)
	set_visual_end(node)
end

--- @param node TSNode
local function visual_select_node_end(node)
	local start = Pos:new(node:start()):to_vim()
	local end_ = Pos:new(node:end_()):to_vim()

	local el = math.min(end_.row, f.line("$"))
	local ec = math.max(end_.col - 1, 0)

	a.nvim_buf_set_mark(0, "<", start.row, start.col, {})
	a.nvim_buf_set_mark(0, ">", el, ec, {})
end

--- Vim is currently in visual charwise mode
--- @return boolean
local function is_visual_charwise()
	return vim.api.nvim_get_mode().mode == "v"
end

local function resume_visual_charwise()
	local visualmode = f.visualmode()
	if ({ ["v"] = true, [""] = true })[visualmode] then
		-- Issue: which-key's ModeChanged logic interferes with the transition to
		-- visual mode (when which-key's auto bindings are enabled in normal
		-- mode).
		-- Fix: An extra gv is harmless, but fixes the issue.
		-- TODO: Figure out better workaround, but a *lot* of Neovimmers use
		-- which-key, so the workaround is probably justified.
		vim.cmd.normal("gv")
		vim.cmd.normal("gv")
	elseif ({ ["V"] = true, ["\22"] = true })[visualmode] then
		-- 22 is the unicode decimal representation of <C-V>
		vim.cmd.normal("gvv")
	end
	assert(vim.fn.mode() == "v", "Failed to resume visual mode")
end

--- @param node TSNode
--- @param range Range4
--- @return boolean
local function node_has_range(node, range)
	return vim.deep_equal({ node:range() }, range)
end

--- Reports if the node is selected, returns false if not currently in visual
--- mode or if visual mode does not perfectly match the node boundaries
--- @param node TSNode
--- @param range Range4
--- @return boolean
local function node_is_selected(node, range)
	return is_visual_charwise() and node_has_range(node, range)
end

---@return treeclimber.Range
function api.buf.get_selection_range()
	local from = a.nvim_win_get_cursor(0)
	-- Note: Returned col index may not be multi-byte safe. (TODO)
	return Range.from_visual(from[1], from[2], f.line("v"), f.col("v"))
end

---Get the node that spans the range
---@param range treeclimber.Range
---@return TSNode?, TSNode?
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
	local range = Range.new(start, end_)
	return api.node.largest_named_descendant_for_range(root, range:to_list())
end

-- Start with the covering node, if the start and end match it's exactly
-- then return it, otherwise find the slice of the node that most closesly
-- matches the selection
--- @param start treeclimber.Pos
--- @param end_ treeclimber.Pos
--- @return TSNode[]
local function get_covering_nodes(start, end_)
	local parent, innermost = get_covering_node(start, end_)

	if parent == nil then
		return {}
	end

	-- If outermost node is exact match, return it; otherwise, look for child node(s).
	if Pos.eq(Pos:new(parent:end_()), end_) and Pos.eq(Pos:new(parent:start()), start) then
		return { parent }
	end

	local nodes = {}

	-- Decide which parent to use: innermost or outermost. Both are larger than the input range.
	-- If innermost parent has no children, prefer the parent (though the choice probably
	-- doesn't matter in that case).
	if innermost:child_count() == 0 then
		-- This handles the case of (eg) select_current_node from normal mode (such that input range is single char wide).
		return { parent }
	end
	-- Loop over children of innermost parent, gathering the relevant subset.
	for child in innermost:iter_children() do
		if child:named() and Pos.gte(Pos:new(child:start()), start) and Pos.lte(Pos:new(child:end_()), end_) then
			table.insert(nodes, child)
		end
	end

	-- Note: If start/end_ is between children, fall back to parent.
	return #nodes > 0 and nodes or { parent }
end

---Get the node that spans the range
---@param node TSNode
---@param range treeclimber.Range
---@return TSNode?
function api.node.named_descendant_for_range(node, range)
	return node:named_descendant_for_range(range:values())
end

---Get the smallest node that spans the range and the largest node co-located with it,
---returning both in the following order: largest, smallest
---TODO: Consider renaming this function whose name is rather misleading.
---@param node TSNode
---@param range Range4
---@return TSNode?, TSNode?
function api.node.largest_named_descendant_for_range(node, range)
	local prev = node:named_descendant_for_range(unpack(range))

	if prev == nil then
		return
	end

	---@type TSNode?
	local next = prev

	local innermost = prev
	repeat
		assert(next, "Expected TSNode")
		prev = next
		next = prev:parent()
	until not next or not vim.deep_equal({ next:range() }, { prev:range() })
	-- Return up to two nodes.
	return prev, innermost
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
--- @param node TSNode
--- @param start treeclimber.Pos
--- @param end_ treeclimber.Pos
local function is_selected_cursor_end(node, start, end_)
	local sr, sc, er, ec = node:range()

	return er == start.row and ec == (start.col + 1) and sr == end_.row and sc == (end_.col - 1)
end

---@deprecated use `is_selected_cursor_start_v2`
---@param node TSNode
---@param start treeclimber.Pos
---@param end_ treeclimber.Pos
local function is_selected_cursor_start(node, start, end_)
	local sr, sc, er, ec = node:range()
	return sr == start.row and sc == start.col and er == end_.row and ec == end_.col
end

---Apply highlights
---@param node TSNode
local function apply_decoration(node)
	argcheck("treeclimber.api.apply_decoration", 1, "userdata", node)

	a.nvim_buf_clear_namespace(0, ns, 0, -1)

	local function cb()
		-- FIXME: expand gets stuck when...
		-- 1. starting on variable name (mode) below
		-- 2. starting on equal
		-- TODO: Try removing the debug statements tomorrow...
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
	local start, end_ = api.buf.get_selection_range():positions()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	clear_history()
	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

function api.select_expand()
	local range = api.buf.get_selection_range()
	local node = get_covering_node(range:positions())

	if not node then
		return
	end

	-- Does selection match covering node? If so, we need to expand; otherwise, the expansion
	-- has already been performed by get_covering_node().
	if node_is_selected(node, range:to_list()) then
		-- Expand the selection.
		node = api.node.grow(node)

		if not node then
			return
		end
		push_history(range:to_list())
	else
		-- Expansion was performed by get_covering_node(). Push range iff it corresponds
		-- exactly to a range of nodes (possibly 1).
		local nodes = get_covering_nodes(range:positions())
		if nodes and #nodes > 0 and Pos:new(nodes[1]:start()) == range.from
			and Pos:new(nodes[#nodes]:end_()) == range.to then
			push_history(range:to_list())
		end
	end
	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

function api.select_shrink()
	-- Design Decision: This function is designed for use with a single starting node, but
	-- nothing precludes its use when multiple nodes are selected; thus, for now, treat
	-- execution with multiple nodes selected as a shrink from the containing parent.
	local range = api.buf.get_selection_range()
	local root = api.buf.get_root()
	local node = api.node.largest_named_descendant_for_range(root, range:to_list())

	if not node then
		return
	end

	-- Get shrink target, which will be either a single child node, or a set of previously
	-- selected children.
	local nodes = api.node.shrink(node)

	-- Treat the single and multi-node cases differently.
	if #nodes == 1 then
		apply_decoration(nodes[1])
		visually_select_node(nodes[1])
	else
		set_visual_start(nodes[1])
		set_visual_end(nodes[#nodes])
	end
	resume_visual_charwise()

end

function api.select_top_level()
	local range = api.buf.get_selection_range()
	local node = get_covering_node(range:positions())

	-- Loop from current selection to top level, pushing a trail of ascended-from nodes as we go.
	-- Note: If the starting selection differs from the covering node, push it before
	-- beginning the ascent.
	if node and not vim.deep_equal({node:range()}, range:to_list())  then
		-- TODO: Decide whether we should push actual treeclimber.Range objects to
		-- permit placing the cursor at the proper (start or end) side of the
		-- selection on shrink.
		push_history(range:to_list())
	end
	-- While current node has a parent (and current node isn't top level), push current and ascend.
	while node and not top_level_types[node:type()] and node:parent() do
		-- Push node before ascending.
		push_history{node:range()}
		node = node:parent()
	end

	if node == nil then
		return
	end

	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

-- TODO: Use TSNode:extra() to skip comments (here and everywhere), but consider how best
-- to make this configurable.
function api.select_forward_end()
	local range = api.buf.get_selection_range()
	local node = get_covering_node(range:positions())

	if node and node_is_selected(node, range:to_list())
		and range.backwards and node:next_named_sibling() then
		-- Current node is already selected with cursor at end, so jump to next.
		node = node:next_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	apply_decoration(node)
	visual_select_node_end(node)
	resume_visual_charwise()
end

function api.select_backward()
	local range = api.buf.get_selection_range()
	local node = get_covering_node(range:positions())

	if node == nil then
		return
	end

	-- TODO: Update comment.
	if node_is_selected(node, range:to_list()) and node:prev_named_sibling() then
		node = node:prev_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

function api.select_siblings_backward()
	local start, end_ = api.buf.get_selection_range():positions()
	local node = get_covering_node(start, end_)

	while node and node:prev_named_sibling() do
		node = node:prev_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

function api.select_siblings_forward()
	local start, end_ = api.buf.get_selection_range():positions()
	local node = get_covering_node(start, end_)

	while node and node:next_named_sibling() do
		node = node:next_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

function api.select_forward()
	local range = api.buf.get_selection_range()
	local node = get_covering_node(range:positions())

	if node == nil then
		return
	end

	if node_is_selected(node, range:to_list()) and node:next_named_sibling() then
		node = node:next_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	apply_decoration(node)
	visually_select_node(node)
	resume_visual_charwise()
end

function api.select_grow_forward()
	local start, end_ = api.buf.get_selection_range():positions()
	local nodes = get_covering_nodes(start, end_)

	if nodes and #nodes > 0 then
		local snode = nodes[1]
		local enode = nodes[#nodes]
		-- Design Decision: Skip unnamed siblings such as equal signs.
		enode = enode:next_named_sibling() or enode
		clear_history()
		set_visual_start(snode)
		set_visual_end(enode)
		resume_visual_charwise()
	end
end

function api.select_grow_backward()
	local start, end_ = api.buf.get_selection_range():positions()
	local nodes = get_covering_nodes(start, end_)

	if nodes and #nodes > 0 then
		local snode = nodes[1]
		local enode = nodes[#nodes]
		snode = snode:prev_named_sibling() or snode
		clear_history()
		set_visual_start(snode)
		set_visual_end(enode)
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

-- Return list of nodes representing the target of the shrink. Targets corresponding to a range
-- previously pushed onto the node stack may span multiple nodes.
-- Note: To simplify caller logic, we always return an array of nodes, even when a range from the
-- stack is not used (in which case, the target is invariably a single node).
---@param node TSNode
---@return TSNode[]
function api.node.shrink(node)
	argcheck("treeclimber.api.node.shrink", 1, "userdata", node)

	if history_size() > 0 then
		--- @type Range4
		local descendant_range
		--- @type boolean
		local colocated, contained

		-- Check stack for a range that's within and not co-located with current node.
		-- Short-circuit and clear stack if popped range is outside provided node.
		-- Rationale:  To keep stack structure simple, we have it maintain history for only
		-- one vertical path at a time.
		repeat
			descendant_range = pop_history()
			contained = descendant_range and vim.treesitter.node_contains(node, descendant_range)
			colocated = vim.deep_equal(descendant_range, { node:range() })
		until history_size() == 0 or not contained or not colocated
		if contained and not colocated then
			assert(
				type(descendant_range) == "table" and #descendant_range == 4,
				string.format("Expected a Range4, got %s", type(descendant_range))
			)

			-- Note: Docs specify that a shrink should "undo previous expand". We
			-- accomplish this by pushing (potentially) multi-node *ranges* to the stack
			-- on ascent and using get_covering_nodes() here on the popped range...
			local nodes = get_covering_nodes(
				Pos:new(descendant_range[1], descendant_range[2]),
				Pos:new(descendant_range[3], descendant_range[4]))
			-- Ignore empty node list (probably shouldn't happen) or list whose
			-- collective range is the same as (or larger than) that of node from which
			-- we're attempting to shrink.
			if not nodes or #nodes == 0 then
				-- TODO: Warn? As long as get_covering_nodes() falls back to parent,
				-- this shouldn't happen.
			elseif Pos:new(nodes[1]:start()) > Pos:new(node:start()) or Pos:new(nodes[#nodes]:end_()) < Pos:new(node:end_()) then
				return nodes
			end
		end
	end

	-- Clear history.
	-- Rationale: We didn't use a range from the stack, which means either the stack is empty or
	-- it contains a different vertical path from the one we're attempting to descend.
	clear_history()

	---@type TSNode?
	local next = node

	local range = Range.from_node(node)

	-- Descend by first child, looking for first node that is not co-located with its parent *or*
	-- has no named children.
	-- Note: If we can't find non co-located node, just return lowest named node, even
	-- if it's the starting node.
	while next and api.node.has_range(next, range) and next:named_child_count() > 0 do
		next = next:named_child(0)
	end

	-- Return array containing a single node.
	return { next }
end

function api.draw_boundary()
	a.nvim_buf_clear_namespace(0, boundaries_ns, 0, -1)

	local pos_ = Pos.to_ts(a.nvim_win_get_cursor(0))
	local node = ts.get_node({ pos = pos_ })
	-- grow selection until it matches one of the types

	local i = 0
	while true do
		if node == nil then
			return
		end

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
	local range = api.buf.get_selection_range()
	local node = get_covering_node(range:positions())

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
