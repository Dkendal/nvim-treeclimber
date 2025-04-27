local ts = vim.treesitter
local f = vim.fn
local a = vim.api
local Config = require('nvim-treeclimber.config')
local Pos = require("nvim-treeclimber.pos")
local Range = require("nvim-treeclimber.range")
local Stack = require("nvim-treeclimber.stack")
local RingBuffer = require("nvim-treeclimber.ring_buffer")
local argcheck = require("nvim-treeclimber.typecheck").argcheck

-- TODO: Remove this once an approach has been finalized.
local CFG_USE_MODE_CHANGED_EVENT = true

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

-- Return nil if provided mode string (default mode()) does not represent any visual mode, else a
-- string indicating which visual mode.
---@param mode? string
---@return "v" | "V" | "\22" | nil
local function in_any_visual_mode(mode)
	mode = mode or f.mode()
	return mode:match('^[vV]') or string.match(mode,
		a.nvim_replace_termcodes("^<C-V>", true, false, true))
end

-- Simulate pressing of <esc>
local function do_escape()
	vim.cmd.normal { a.nvim_replace_termcodes("<esc>", true, false, true), bang = true }
end

-- Ensure we're in Normal mode, pressing <esc> only if necessary.
-- Rationale: Avoid unnecessary beeps.
local function ensure_normal_mode()
	if in_any_visual_mode() then
		do_escape()
	end
end

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
-- Note: Changed type of range from Range4 to 4-tuple, since the type annotation system complains
-- when the Range4 returned by node:range() is passed to push_history().
--- @param range [integer, integer, integer, integer]
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

-- Visually select the input treeclimber Range.
---@param range treeclimber.Range # TSNode with [0,0) indexing
---@param reverse boolean? # leave cursor at end of range
local function visually_select_range(range, reverse)
	-- Convert range from TSNode [0,0) to Vim [1,0] indexing and ensure range is entirely within current
	-- buffer. (See note on buf_limited().)
	range = range:buf_limited():to_vim()
	-- Ensure we're not still in some sort of visual mode.
	ensure_normal_mode()
	-- Move to end of node.
	-- Rationale: Select from end to start to leave cursor at start (the common case).
	vim.api.nvim_win_set_cursor(0, {range.to:values()})
	-- Start visual mode.
	vim.cmd.normal "v"
	-- Move to start of node.
	vim.api.nvim_win_set_cursor(0, {range.from:values()})

	if reverse then
		-- Leave cursor at end of selection.
		vim.cmd.normal "o"
	end
	assert(vim.fn.mode() == "v", "Failed to resume visual mode: " .. f.mode())
end

-- Convenience function to select a range of nodes
---@param nodes TSNode[]
---@param reverse boolean?
local function visually_select_nodes(nodes, reverse)
	visually_select_range(Range.from_nodes(nodes[1], nodes[#nodes]), reverse)
end

-- Convenience function to select a single node
---@param node TSNode
---@param reverse boolean?
local function visually_select_node(node, reverse)
	visually_select_range(Range.from_node(node), reverse)
end

--- Vim is currently in visual charwise mode
--- @return boolean
local function is_visual_charwise()
	return vim.api.nvim_get_mode().mode == "v"
end

-- FIXME: This function is broken. It's currently used only by highlight_external_definitions(),
-- which I'm not convinced really needs it. The problem is that it doesn't properly account for all
-- the idiosyncrasies of vim.fn.visualmode(), which behaves differently when visual mode is
-- currently active (which it may be when this function is called). To further complicate matters,
-- the visual marks were being adjusted with visual mode active, just before this function was
-- called. To complicate matters even further, the normal mode gv was somehow being "eaten" by the
-- very popular 'which-key' plugin, resulting in a fatal error from the assert().
-- Bottom Line: This is not the most straightforward way to perform the desired selection.
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

-- TODO: Consider refactoring to ensure more consistent behavior between linewise and characterwise
-- visual modes.
-- Rationale: The use of line("v")/col("v") in this function makes sense for characterwise visual
-- mode, but can produce unexpected results in linewise visual mode: e.g., a single line selection
-- tends to return a zero-width selection in linewise visual mode.
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

-- Accepts an ancestor node and a table of presumably descendant siblings and returns either the
-- highest ancestor of the table nodes that's visually distinct from the input ancestor, else the
-- input table itself, assuming the range it represents is smaller than the range of the input
-- ancestor, else nil.
---@param ancestor TSNode
---@param nodes TSNode[]
---@return TSNode[] | nil
local function get_nearest_descendant_containing(ancestor, nodes)
	---@type treeclimber.Range
	local ancestor_range = Range.new4(ancestor:range())
	---@type TSNode?
	local node = nodes and #nodes > 0 and nodes[1] or nil

	if not node then
		-- Bad input
		return nil
	end
	if #nodes > 1 and not ancestor_range:contains(
		Range.new(Pos:new(nodes[1]:start()), Pos:new(nodes[#nodes]:end_()))) then
		-- Input sequence of nodes is not fully (visibly) contained by ancestor, and is thus
		-- not a valid return.
		return nil
	end
	---@type TSNode?
	local maybe
	-- If here, we're guaranteed a non-empty set of nodes for return.
	repeat
		-- Tentatively advance, though we still may reject this candidate.
		-- Note: node is non-null and will be updated only on acceptance.
		maybe = node:parent()
		if maybe then
			local maybe_range = Range.new4(maybe:range())
			if maybe ~= ancestor and ancestor_range:contains(maybe_range) then
				-- Accept the candidate.
				node = maybe
			else
				-- Ceiling reached.
				break
			end
		end
	until not maybe
	-- Return highest node reached (in a table of one node) or the input table of nodes (if we
	-- didn't ascend).
	return node == nodes[1] and nodes or {node}
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

-- Get a node above this one that would grow the selection, returning the outermost of multiple
-- colocated nodes.
---@param node TSNode
---@return TSNode
function api.get_larger_ancestor(node)
	---@type treeclimber.Range
	local range = Range.from_node(node)
	---@type treeclimber.Range
	local next_range
	---@type TSNode?
	local next
	---@type integer Number of times range has increased
	local inc_cnt = 0
	-- Logic: Attempt to expand twice, taking the last node accepted *before* the second
	-- expansion.
	repeat
		next = node:parent()
		if next then
			next_range = Range.from_node(next)
			if next_range ~= range then
				-- Range increase has occurred!
				inc_cnt = inc_cnt + 1
				if inc_cnt > 1 then
					-- On second increase, break without updating node.
					break
				end
				range = next_range
			end
			-- Save the best candidate so far.
			node = next
		end
	until not next
	return node
end

---@return {Selection: vim.api.keyset.keymap,
---         SiblingStart: vim.api.keyset.keymap,
---         Sibling: vim.api.keyset.keymap,
---         Parent: vim.api.keyset.keymap,
---         ParentStart: vim.api.keyset.keymap}
local function get_active_highlights()
	return vim.iter(vim.tbl_keys(Config:get_default("display.regions.highlights")))
		:map(function(k) return {k, a.nvim_get_hl(0, {name = k})} end)
		:filter(function(kv) return not vim.tbl_isempty(kv[2]) end)
		:fold({}, function(acc, kv) acc[kv[1]] = kv[2]; return acc end)

end


-- Clear any leftover extmarks from our namespace and register callback to clear the ones we're
-- about to create when they're no longer needed.
local function clear_namespace()
	a.nvim_buf_clear_namespace(0, ns, 0, -1)

	if not CFG_USE_MODE_CHANGED_EVENT then
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
	else
		-- Note: The only drawback to this approach is that, because of the
		-- ensure_normal_mode() call in visually_select_range(), it will cancel old and
		-- create new autocommand on each treeclimber traversal.
		a.nvim_create_autocmd({"ModeChanged"}, {
			-- Design Decision: Could use explicit pattern since we know we should be in visual
			-- mode, but the match in the callback is more conservative.
			--pattern = "v:*",
			-- Design Decision: Returning true from callback to delete autocmd after
			-- match succeeds is safer.
			--once = true,
			callback = function(t)
				-- Get the second component of the event string (current mode).
				if f.split(t.match, ":")[2] ~= "v" then
					a.nvim_buf_clear_namespace(0, ns, 0, -1)
					-- Return true to delete autocommand.
					return true
				end
			end,
		})
	end
end

-- Apply highlights to various regions, defined relative to the selected node.
-- Important Note: Although it is possible to set the priority of the highlights attached to
-- extmarks explicitly using the 'priority' field of the option table passed to
-- nvim_buf_set_extmark(), this function omits the 'priority' field and relies instead on the order
-- in which the extmarks are created. To understand how this works, visualize a virtual, sorted
-- list of extmarks, in which the highlighting of later marks overrides that of earlier marks. Marks
-- are added by nvim_buf_set_extmark(), which maintains the sort order according to the following
-- logic... To find the position at which to insert the new mark, traverse the list from the start,
-- looking for the first mark that meets either of the following conditions:
-- 1. start point is past start point of the inserted mark
-- 2. hl_group is different from inserted mark's hl_group, but both the hl_group and start position
--    of the previous mark match those of the inserted mark.
-- If such a mark is found, the new mark is added before it; otherwise the new mark is appended.
-- Another way of visualizing it is that the list is sorted first by mark start point, but multiple
-- marks added at the same start point undergo an order-preserving sort by hl_group, in which the
-- relative ordering of the hl_groups is determined by the insert time of the first mark added to
-- the group at that start position.
-- @param node TSNode
local function apply_decoration(node)
	argcheck("treeclimber.api.apply_decoration", 1, "userdata", node)

	clear_namespace()

	-- Find out which regions are active so we can avoid setting marks for ones that aren't.
	local regions = get_active_highlights()

	-- Determine whether attributes bleed through from Parent to Siblings.
	local inherit_attrs = Config:get("display.regions.inherit_attrs")

	-- Highlight the currently selected node.
	if regions.Selection then
		local sl, sc = unpack({ node:start() })
		local el, ec = unpack({ node:end_() })
		a.nvim_buf_set_extmark(0, ns, sl, sc, {
			hl_group = "Selection",
			strict = false,
			end_line = el,
			end_col = ec,
		})
	end

	local parent = node:parent()
	if parent then
		local psl, psc = unpack({ parent:start() })
		local pel, pec = unpack({ parent:end_() })
		-- Save a copy of parent start pos that won't be updated in loop.
		local psl_, psc_ = psl, psc

		if regions.Parent and inherit_attrs then
			-- Create single Parent region to span all Siblings.
			-- Note: Creating before any Siblings ensures the latter's colors will take
			-- precedence in areas of overlap; attrs like bold and italic, however, will
			-- bleed through.
			if psl < pel or psc < pec then
				a.nvim_buf_set_extmark(0, ns, psl, psc, {
					hl_group = "Parent",
					strict = false,
					end_line = pel,
					end_col = pec,
				})
			end
		end
		-- Loop over children, creating regions for named children only.
		-- Note: If not inherit_attrs, we'll also be creating discontiguous Parent regions
		-- in the space between siblings.
		-- Rationale: This is the only way to ensure that attributes like bold and italic
		-- don't "bleed through" the Sibling.
		-- TODO: If the Parent highlight contains only fg/bg colors (no bold, italic, etc.),
		-- we could probably create a single Parent that spans all.
		for child in parent:iter_children() do
			-- Note: Current Parent segment is ended only by a named child.
			if child:named() then
				local csl, csc = unpack({ child:start() })
				local cel, cec = unpack({ child:end_() })
				if Pos:new(csl, csc) < Pos:new(psl, psc) then
					csl, csc = psl, psc
				end
				-- Don't highlight the current node as sibling.
				if child:id() ~= node:id() then
					if regions.SiblingStart then
						a.nvim_buf_set_extmark(0, ns, csl, csc, {
							hl_group = "SiblingStart",
							strict = false,
							end_col = csc + 1,
						})
					end

					if regions.Sibling then
						-- Caveat: Skip the first char of sibling iff
						-- SiblingStart group enabled.
						a.nvim_buf_set_extmark(0, ns, csl,
							regions.SiblingStart and csc + 1 or csc, {
							hl_group = "Sibling",
							strict = false,
							end_line = cel,
							end_col = cec,
							--priority = pris.Sibling,
						})
					end
				end
				if regions.Parent and not inherit_attrs then
					if psl < csl or psc < csc then
						-- Close current parent region (if nonzero width).
						a.nvim_buf_set_extmark(0, ns, psl, psc, {
							hl_group = "Parent",
							strict = false,
							end_line = csl,
							end_col = csc,
						})
					end
					-- End of sibling begins new parent region.
					psl, psc = cel, cec
				end
			end
		end
		if regions.Parent and not inherit_attrs then
			-- Create the final discontiguous Parent region (iff it's nonzero length).
			if psl < pel or psc < pec then
				a.nvim_buf_set_extmark(0, ns, psl, psc, {
					hl_group = "Parent",
					strict = false,
					end_line = pel,
					end_col = pec,
				})
			end
		end
		-- This region is placed last to make it highest priority.
		-- Rationale: Always show the start of the parent, even at the expense of obscuring
		-- first char of first child.
		if regions.ParentStart then
			a.nvim_buf_set_extmark(0, ns, psl_, psc_, {
				hl_group = "ParentStart",
				strict = false,
				end_col = psc_ + 1,
			})
		end
	end
end

function api.select_current_node()
	local start, end_ = api.buf.get_selection_range():positions()
	local node = get_covering_node(start, end_)

	if node == nil then
		return
	end

	-- Design Decision: select_current_node clears node stack.
	clear_history()
	visually_select_node(node)
	apply_decoration(node)
end

-- FIXME: Looks like maybe we're getting a nil when we try to climb too high!
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
	visually_select_node(node)
	apply_decoration(node)
end

function api.select_shrink()
	-- Design Decision: This function is designed for use with a single starting node, but
	-- nothing precludes its use when multiple nodes are selected; thus, for now, treat
	-- execution with multiple nodes selected as a shrink from the containing parent.
	-- Note: In rare cases, this could result in a descent to already selected children, but it
	-- will self-correct (since descended-to range will be popped from stack), and it will
	-- happen only when user performs certain unlikely sequences outside treeclimber.
	local range = api.buf.get_selection_range()
	local nodes = get_covering_nodes(range.from, range.to)



	if not nodes or #nodes == 0 then
		return
	end

	-- Get shrink target, which will be either a single child node, or a set of previously
	-- selected children.
	nodes = api.node.shrink(nodes)

	-- Treat the single and multi-node cases differently.
	if #nodes == 1 then
		visually_select_node(nodes[1])
	elseif #nodes > 1 then
		visually_select_nodes(nodes)
	end
	apply_decoration(nodes[1])

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

	visually_select_node(node)
	apply_decoration(node)
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
	visually_select_node(node, true)
	apply_decoration(node)
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
	visually_select_node(node)
	apply_decoration(node)
end

function api.select_first_sibling()
	local start, end_ = api.buf.get_selection_range():positions()
	local node = get_covering_node(start, end_)

	while node and node:prev_named_sibling() do
		node = node:prev_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	visually_select_node(node)
	apply_decoration(node)
end

-- TODO: Consider whether it would be better to select first or last sibling *at same level* as
-- multiply-selected nodes. (Current logic will select first or last sibling of parent when multiple
-- nodes are selected.)
function api.select_last_sibling()
	local start, end_ = api.buf.get_selection_range():positions()
	local node = get_covering_node(start, end_)

	while node and node:next_named_sibling() do
		node = node:next_named_sibling()
	end

	if node == nil then
		return
	end

	clear_history()
	visually_select_node(node)
	apply_decoration(node)
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
	visually_select_node(node)
	apply_decoration(node)
end

function api.select_grow_forward()
	local start, end_ = api.buf.get_selection_range():positions()
	local nodes = get_covering_nodes(start, end_)

	if nodes and #nodes > 0 then
		local snode = nodes[1]
		local enode = nodes[#nodes]
		-- Design Decision: Skip unnamed siblings such as equal signs.
		enode = enode:next_named_sibling() or enode
		-- Design Decision: Don't clear history, since growing selection doesn't invalidate existing path.
		visually_select_range(Range.from_nodes(snode, enode))
	end
end

function api.select_grow_backward()
	local start, end_ = api.buf.get_selection_range():positions()
	local nodes = get_covering_nodes(start, end_)

	if nodes and #nodes > 0 then
		local snode = nodes[1]
		local enode = nodes[#nodes]
		snode = snode:prev_named_sibling() or snode
		-- Design Decision: Don't clear history, since growing selection doesn't invalidate existing path.
		visually_select_range(Range.from_nodes(snode, enode))
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
	if not node then
		-- Note: This is really probably an internal error; consider assert().
		return nil
	end
	return api.get_larger_ancestor(node)
end

---@param nodes TSNode[]
---@param range treeclimber.Range
---@return TSNode | nil
local function get_node_containing_range(nodes, range)
	if Range.from_nodes(nodes[1], nodes[#nodes]):covers(range) then
		for _, n in ipairs(nodes) do
			if Range.from_node(n):covers(range) then
				return n
			end
		end
	end
	return nil
end

-- Helper function for api.node.shrink, which uses node stack to try to find a shrink target,
-- returning either a table of target nodes or nil.
---@param anodes TSNode[]
---@return TSNode[] | nil
local function try_shrink_from_history(anodes)
	---@type treeclimber.Range # ancestor range.
	local arange = Range.from_nodes(anodes[1], anodes[#anodes])

	if history_size() > 0 then
		-- Check stack for a range that's visibly contained by current node(s).
		-- Short-circuit and clear stack if we encounter a range that's outside provided node(s).
		-- Rationale: To keep stack structure simple, we have it maintain history for only
		-- one vertical path at a time.
		---@type treeclimber.Range
		local drange -- descendant range
		---@type TSNode[] # descendant nodes
		local dnodes
		---@type boolean # loop conditions
		local contained, overlapping
		repeat
			local drange4 = pop_history()
			-- TODO: Should we assert here, or just let the if below discard invalid stack entries?
			assert(
				type(drange4) == "table" and #drange4 == 4,
				string.format("Expected a Range4, got %s", type(drange4))
			)
			if drange4 then
				drange = Range.new4(unpack(drange4))
				-- Get set of nodes corresponding precisely to popped range.
				-- Note: Docs specify that a shrink should "undo previous expand",
				-- which requires us to handle multi-node shrink targets.
				dnodes = get_covering_nodes(drange.from, drange.to)
				if dnodes then
					-- Adjust the popped range to match dnodes.
					drange = Range.from_nodes(dnodes[1], dnodes[#dnodes])
					-- Design Decision: If stack contains a range representing a
					-- strict subset of the currently selected nodes, return it.
					if arange:contains(drange) and dnodes[1]:parent() == anodes[1]:parent() then
						return dnodes
					end
					contained = Range.contains(arange, drange)
					overlapping = contained or arange:overlaps(drange)
				end
			end
		until history_size() == 0 or not overlapping or contained
		if contained then
			-- The logic below ensures that if user manually (apart from treeclimber)
			-- moves cursor higher in the tree, then performs a shrink not preceded by
			-- select_current() (which currently clears stack), descent will follow the
			-- nodes that would have been pushed to the stack if he'd ascended normally
			-- using treeclimber expand.
			-- Arrival here implies dnodes is not a strict subset of anodes, and thus
			-- must be wholly *within* one of anodes. Find out which...
			local node = get_node_containing_range(anodes, drange)
			if node then
				-- Get set of nodes that lies no more than one level below node:
				-- either the original nodes table or an ancestor between node and
				-- nodes.
				dnodes = get_nearest_descendant_containing(node, dnodes) or {}
				if dnodes and #dnodes > 0 then
					-- If the adjusted range is larger than the popped range,
					-- re-push the latter to support subsequent shrink.
					local adj_range = Range.from_nodes(dnodes[1], dnodes[#dnodes])
					if adj_range:contains(drange) then
						push_history(drange:to_list())
					end
					return dnodes
				end
			end
		end
	end
	return nil
end

-- Return table of nodes representing the target of the shrink, which could be either a single node
-- or a sequence of nodes corresponding to a range previously pushed to the stack.
-- Note: To simplify caller logic, we always return a table of nodes, even when a range from the
-- stack is not used ({node}) or no target exists ({}).
---@param anodes TSNode[]
---@return TSNode[]
function api.node.shrink(anodes)
	argcheck("treeclimber.api.node.shrink", 1, "table", anodes)

	-- First try to determine target using node stack.
	local nodes = try_shrink_from_history(anodes)
	if nodes then return nodes end

	-- We didn't use a range from the stack, which means either the stack is empty or it its top
	-- entry is not a valid shrink target.
	clear_history()

	if #anodes > 1 then
		-- Design Decision: Shrinking from a multi-node selection selects first selected
		-- node.
		return {anodes[1]}
	end

	-- Starting from single node.
	local node = anodes[1]
	local range = Range.from_node(node)

	-- Descend by first child, looking for first named node that is visibly within its parent.
	-- If we hit leaf without encountering such a node, just keep the starting node.
	---@type TSNode?
	local next = node
	repeat
		next = next and next:named_child(0)
		if next then
			-- Is this child visibly within?
			if range:contains(Range.from_node(next)) then
				node = next
				break
			end
		end
	until not next

	-- Return table containing a single node.
	return { node }
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
	-- TODO: If the purpose of this to ensure there's a current selection, not sure it's needed,
	-- since comment says "currently selected".
	do_escape()
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
