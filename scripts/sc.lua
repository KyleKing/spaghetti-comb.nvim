-- Headless entry point for `scripts/sc`. Resolves the plugin root from the
-- script's own path so the CLI works from any cwd, then prints the dispatch
-- result as JSON and exits 0/1.
local script = arg and arg[0] or ""
local root = vim.fn.fnamemodify(script, ":h:h")
vim.opt.runtimepath:prepend(root)

-- codanna.nvim is not on this minimal runtimepath; a stub core lets the
-- adapter self-exec with the default (or $CODANNA_PATH) binary.
local codanna = require("spaghetti-comb.substrate.codanna")
codanna._core = { config = { codanna_path = vim.env.CODANNA_PATH or "codanna" } }

local ok, result, err = pcall(require("spaghetti-comb.cli").run, arg or {})
if not ok then
    io.stderr:write("sc: " .. tostring(result) .. "\n")
    os.exit(1)
end
if err then
    io.stderr:write(err .. "\n")
    os.exit(1)
end
io.stdout:write(vim.json.encode(result) .. "\n")
