(local queries (require :nvim-treesitter.query))
(local define-modules (. (require :nvim-treesitter) :define_modules))

(local M {})

; (fn is-supported [lang]
;   (not= (queries.get_query lang :treeclimber) nil))

(fn is-supported [lang]
  true)

(fn M.init []
  (define-modules {:treeclimber {:module_path :nvim-treeclimber.internal
                                 :is_supported is-supported}}))

M

