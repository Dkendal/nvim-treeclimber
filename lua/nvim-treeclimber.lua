local queries = require "nvim-treesitter.query"

local M = {}

-- TODO: In this function replace `nvim-treesitter` with the actual name of your module.
function M.init()
  require"nvim-treesitter".define_modules {
    module_template = {
      module_path = "nvim-treesitter.internal",
      is_supported = function(lang)
        -- TODO: you don't want your queries to be named `awesome-query`, do you ?
        return queries.get_query(lang, 'treeclimber') ~= nil
      end,
    },
  }
end

return M
