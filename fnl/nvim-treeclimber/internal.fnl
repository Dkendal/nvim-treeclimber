(local parsers (require :nvim-treesitter.parsers))
(local configs (require :nvim-treesitter.configs))
(local ts_utils (require :nvim-treesitter.ts_utils))
(local query (require :nvim-treesitter.query))
(local query (require :nvim-treesitter.query))
(local api vim.api)
(local ex vim.cmd)
(local luv vim.loop)
(local pack table.pack)

(local nvim {})
(setmetatable nvim {:__index #(. vim.api (.. :nvim_ $2))})

(local M {})

(fn get-node []
  (local [row col] (vim.api.nvim_win_get_cursor 0))
  (local root_lang_tree (parsers.get_parser))
  (local range [(- row 1) col (- row 1) col])
  (when root_lang_tree
    (local owning_lang_tree (root_lang_tree:language_for_range range))
    (var result nil)
    (each [_ tree (ipairs (owning_lang_tree:trees)) :until result]
      (local root (tree:root))
      (local node (root:descendant_for_range (unpack range)))
      (when node
        (set result node)))
    result))

(fn node-get-next-sibling [node]
  (local parent (node:parent))
  (when parent
    (var result nil)
    (var done false)
    (each [sibling field (parent:iter_children) :until result]
      (when done
        (set result sibling))
      (when (= sibling node)
        (set done true)))
    (if result
        result
        (node-get-next-sibling (node:parent)))))

(fn node-get-prev-sibling [node]
  (local parent (node:parent))
  (when parent
    (var result nil)
    (each [sibling field (parent:iter_children) :until (= sibling node)]
      (set result sibling))
    (if result
        result
        (node-get-prev-sibling (node:parent)))))

(fn v2+ [x y]
  (match [x y]
    [[a1 a2] [b1 b2]] [(+ a1 b1) (+ a2 b2)]
    _ (error (.. "no-match: " (vim.inspect _)))))

(fn v2= [x y]
  (match [x y]
    [[a b] [a b]] true
    [[a1 b1] [a2 b2]] false
    _ (error (.. "no-match: " (vim.inspect _)))))

(fn node-cursor-start [node]
  (local (row col) (node:start))
  (v2+ [row col] [1 0]))

(fn node-cursor-start? [node pos]
  (v2= (node-cursor-start node) pos))

(fn M.move-to [func]
  (var node (get-node))
  (when node
    ;; TODO shouldn't always move to the start ; (local pos (nvim.win_get_cursor 0)) ; (while (and current-node (node-cursor-start? current-node pos))
    (local current-node (func node))
    (when current-node
      (nvim.win_set_cursor 0 (node-cursor-start current-node)))))

(fn M.move-to-parent []
  (local pos (nvim.win_get_cursor 0))
  (M.move-to (fn [node]
               (var curr node)
               (while (and curr (node-cursor-start? curr pos))
                 (set curr (curr:parent)))
               curr)))

(fn M.move-to-next-sibling []
  (M.move-to #(node-get-next-sibling $1)))

(fn M.move-to-prev-sibling []
  (M.move-to #(node-get-prev-sibling $1)))

(fn M.attach [bufnr lang]
  (ex "command! -buffer TCMoveToParent :lua require'nvim-treeclimber.internal'['move-to-parent']()")
  (ex "nno <silent> <buffer> J :TCMoveToParent<CR>")
  (ex "nno <silent> <buffer> L :lua require'nvim-treeclimber.internal'['move-to-next-sibling']()<cr>")
  (ex "nno <silent> <buffer> H :lua require'nvim-treeclimber.internal'['move-to-prev-sibling']()<cr>")
  (ex "command! -buffer TC :lua require'nvim-treeclimber.internal'.call()"))

(fn M.detach [bufnr]
  ;; TODO: Fill this with what you need to do when detaching from a buffer
  )

M

