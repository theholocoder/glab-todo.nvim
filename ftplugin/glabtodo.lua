-- ftplugin for glabtodo buffers (glab-todo plugin).
-- Sets comfortable local options for browsing and editing the todos list.

vim.opt_local.cursorline  = true    -- highlight the current line for easy reading
vim.opt_local.wrap        = false   -- the columnar layout is wide; no wrapping
vim.opt_local.modifiable  = true    -- user must be able to delete lines
vim.opt_local.buflisted   = false   -- keep it out of the buffer list / :ls
vim.opt_local.number      = false   -- line numbers not useful here
vim.opt_local.signcolumn  = "no"    -- no sign column needed
vim.opt_local.spell       = false   -- no spell-check on data lines
