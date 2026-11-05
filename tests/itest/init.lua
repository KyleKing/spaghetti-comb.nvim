-- Minimal init for PTY integration scenarios (nvim -u tests/itest/init.lua).
-- Isolates from user config and packages: only this plugin and the vendored
-- mini.nvim are on the runtimepath. SC_PLUGIN_ROOT is set by run.sh/pty.sh.
-- XDG_DATA_HOME is pointed at a temp dir by the runner so trail persistence
-- never touches real user data.
local root = assert(vim.env.SC_PLUGIN_ROOT, "SC_PLUGIN_ROOT not set")
vim.opt.runtimepath:prepend(root .. "/deps/mini.nvim")
vim.opt.runtimepath:prepend(root)
-- codanna.nvim is an optional sibling checkout; when present the codanna
-- substrate works end-to-end, when absent those commands surface the
-- missing-plugin error (itself a valid DX check).
local codanna_nvim = vim.env.SC_CODANNA_NVIM or (root .. "/../codanna.nvim")
if vim.uv.fs_stat(codanna_nvim .. "/lua/codanna/core.lua") then vim.opt.runtimepath:prepend(codanna_nvim) end

require("spaghetti-comb").setup()
