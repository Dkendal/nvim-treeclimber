---@meta

--- Returns the root node of the syntax tree.
--- @param tree vim.treesitter.LanguageTree # The syntax tree.
--- @return TSNode # The root node.
function vim.treesitter.get_root(tree) end

--- @class vim.treesitter.GetNodeOpts
--- @field bufnr integer? # Buffer number (nil or 0 for current buffer)
--- @field pos integer[]? # 0-indexed (row, col) tuple. Defaults to cursor position in the current window. Required if {bufnr} is not the current buffer
--- @field lang string? # Parser language. (default: from buffer filetype)
--- @field ignore_injections boolean? # Ignore injected languages (default true)
---
--- Gets a specific node in the syntax tree.
--- @param opts? vim.treesitter.GetNodeOpts # The options for getting the node.
--- @return TSNode? # The requested node.
function vim.treesitter.get_node(opts) end

--- @param lang string Language to use for the query
--- @param query string Query in s-expr syntax
--- @return vim.treesitter.Query Parsed query
function vim.treesitter.query.parse(lang, query) end

--- @param dest TSNode Possible ancestor
--- @param source TSNode Possible descendant
--- @return boolean # True if {dest} is an ancestor of {source}
function vim.treesitter.is_ancestor(dest, source) end

--- @param node TSNode Node defining the range
--- @param line integer Line (0-based)
--- @param col integer Column (0-based)
--- @return boolean # True if the position is in node range
function vim.treesitter.is_in_node_range(node, line, col) end

--- @param node TSNode
--- @param range Range4
--- @return boolean
function vim.treesitter.node_contains(node, range) end

--- @param node TSNode
--- @param source integer|string? # Buffer or string from which the {node} is extracted
--- @param metadata vim.treesitter.query.TSMetadata?
--- @return Range6
function vim.treesitter.get_range(node, source, metadata) end

--- @param str string # Text to parse
--- @param lang string # Language of this string
--- @param opts table? # Options to pass to the created language tree
--- @return vim.treesitter.LanguageTree
function vim.treesitter.get_string_parser(str, lang, opts) end

--- @param bufnr integer # Buffer number (0 for current buffer)
--- @param row integer # Position row
--- @param col integer # Position column
--- @return {capture: string, lang: string, metadata: table}[]
function vim.treesitter.get_captures_at_pos(bufnr, row, col) end

--- @param winnr integer? # Window handle or 0 for current window (default)
--- @return string[] # List of capture names
function vim.treesitter.get_captures_at_cursor(winnr) end
